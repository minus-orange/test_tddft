#!/bin/sh
set -eu

# Profile one prepared FPSEID21 TDDFT GPU run with Nsight Systems.
# The trace is diagnostic only and must not be used as a wall-time baseline.
#
# Usage:
#   LABEL=nvhpc_cufft_1rank_02_STEP27_NSYS_01 \
#     ./tools/profile_tddft_nsys.sh ./run/Si111-H_nvhpc
#
# Environment:
#   LABEL          required, monotonic archive label
#   TDDFT_INPUT    default: Si111-H_tm.in_100steps
#   TDDFT_EXE      default: <repo>/FPSEID21/tddft_2022October/tddft_exe
#   NSYS           default: nsys
#   NSYS_TRACE     default: cuda,openacc,nvtx,osrt
#   MPIRUN         default: mpirun
#   MPIRUN_FLAGS   default: --quiet
#   NPROCS         default: 1
#   NSYS_ROOT      default: <repo>/run/nsys_archives
#   CUDA_VISIBLE_DEVICES default: 0
#   DRY_RUN        set to 1 to print the resolved run without executing it

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ "$#" -ne 1 ]; then
  echo "Usage: LABEL=<label> $0 RUN_DIR" >&2
  exit 2
fi

if [ ! -d "$1" ]; then
  echo "ERROR: run directory does not exist: $1" >&2
  exit 1
fi
RUN_DIR=$(CDPATH= cd -- "$1" && pwd)
LABEL=${LABEL:-}
if [ -z "$LABEL" ]; then
  echo "ERROR: LABEL is required." >&2
  exit 2
fi
case "$LABEL" in
  *[!A-Za-z0-9_.-]*)
    echo "ERROR: LABEL contains unsupported characters: $LABEL" >&2
    exit 2
    ;;
esac

TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_100steps}
TDDFT_EXE=${TDDFT_EXE:-"$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"}
NSYS=${NSYS:-nsys}
NSYS_TRACE=${NSYS_TRACE:-cuda,openacc,nvtx,osrt}
MPIRUN=${MPIRUN:-mpirun}
MPIRUN_FLAGS=${MPIRUN_FLAGS:---quiet}
NPROCS=${NPROCS:-1}
NSYS_ROOT=${NSYS_ROOT:-"$ROOT_DIR/run/nsys_archives"}
DRY_RUN=${DRY_RUN:-0}

case "$TDDFT_EXE" in
  /*) ;;
  *)
    exe_dir=$(CDPATH= cd -- "$(dirname -- "$TDDFT_EXE")" && pwd)
    TDDFT_EXE=$exe_dir/$(basename "$TDDFT_EXE")
    ;;
esac

INPUT_PATH=$RUN_DIR/$TDDFT_INPUT
if [ ! -f "$INPUT_PATH" ]; then
  echo "ERROR: TDDFT input does not exist: $INPUT_PATH" >&2
  exit 1
fi
if [ ! -x "$TDDFT_EXE" ]; then
  echo "ERROR: TDDFT executable is not executable: $TDDFT_EXE" >&2
  exit 1
fi

ARCHIVE_DIR=$NSYS_ROOT/$LABEL
if [ -e "$ARCHIVE_DIR" ]; then
  echo "ERROR: Nsight archive already exists: $ARCHIVE_DIR" >&2
  exit 1
fi

REPORT_BASE=$ARCHIVE_DIR/tddft_nsys
TDDFT_OUT=$ARCHIVE_DIR/tddft.out
TDDFT_ERR=$ARCHIVE_DIR/tddft.err

echo "Nsight Systems TDDFT diagnostic run"
echo "  label:      $LABEL"
echo "  run dir:    $RUN_DIR"
echo "  input:      $TDDFT_INPUT"
echo "  executable: $TDDFT_EXE"
echo "  trace:      $NSYS_TRACE"
echo "  output:     $ARCHIVE_DIR"

if [ "$DRY_RUN" = 1 ]; then
  echo "  dry run:    yes"
  exit 0
fi

if ! command -v "$NSYS" >/dev/null 2>&1; then
  echo "ERROR: Nsight Systems command was not found: $NSYS" >&2
  exit 1
fi
if ! command -v "$MPIRUN" >/dev/null 2>&1; then
  echo "ERROR: MPI launcher was not found: $MPIRUN" >&2
  exit 1
fi

mkdir -p "$ARCHIVE_DIR"
cp -p "$INPUT_PATH" "$ARCHIVE_DIR/$TDDFT_INPUT"

export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

created_at=$(date '+%Y%m%d_%H%M%S')
git_revision=$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)
git_branch=$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || true)
nsys_version=$($NSYS --version 2>&1 || true)

{
  echo "created_at=$created_at"
  echo "label=$LABEL"
  echo "git_revision=$git_revision"
  echo "git_branch=$git_branch"
  echo "run_dir=$RUN_DIR"
  echo "tddft_input=$TDDFT_INPUT"
  echo "tddft_exe=$TDDFT_EXE"
  echo "nprocs=$NPROCS"
  echo "nsys_trace=$NSYS_TRACE"
  echo "omp_num_threads=$OMP_NUM_THREADS"
  echo "omp_stacksize=$OMP_STACKSIZE"
  echo "cuda_visible_devices=$CUDA_VISIBLE_DEVICES"
  echo "nsys_version=$nsys_version"
} > "$ARCHIVE_DIR/manifest.env"

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -q > "$ARCHIVE_DIR/nvidia-smi-q.txt" 2>&1 || true
fi

cd "$RUN_DIR"
ulimit -s unlimited 2>/dev/null || true

# MPIRUN_FLAGS is intentionally split so callers can pass multiple launcher
# options. LABEL validation and fixed paths keep the generated archive scoped.
# shellcheck disable=SC2086
"$NSYS" profile \
  --trace="$NSYS_TRACE" \
  --sample=none \
  --cpuctxsw=none \
  --cuda-memory-usage=true \
  --force-overwrite=true \
  --output="$REPORT_BASE" \
  "$MPIRUN" $MPIRUN_FLAGS -np "$NPROCS" "$TDDFT_EXE" \
  < "$INPUT_PATH" > "$TDDFT_OUT" 2> "$TDDFT_ERR"

REPORT_FILE=$REPORT_BASE.nsys-rep
if [ ! -f "$REPORT_FILE" ]; then
  echo "ERROR: Nsight report was not produced: $REPORT_FILE" >&2
  exit 1
fi

STATS_ERRORS=$ARCHIVE_DIR/nsys-stats-errors.txt
: > "$STATS_ERRORS"
for report in \
  cuda_gpu_kern_sum \
  cuda_gpu_mem_time_sum \
  cuda_gpu_mem_size_sum \
  cuda_api_sum \
  openacc_sum
do
  csv=$ARCHIVE_DIR/$report.csv
  if ! "$NSYS" stats --report "$report" --format csv "$REPORT_FILE" \
      > "$csv" 2>> "$STATS_ERRORS"; then
    rm -f "$csv"
    echo "WARNING: Nsight report is unavailable: $report" >&2
  fi
done

SUMMARY=$ARCHIVE_DIR/nsys-summary.txt
{
  echo "FPSEID21 Step27 Nsight Systems summary"
  echo "label=$LABEL"
  echo "git_revision=$git_revision"
  echo "Diagnostic trace only; do not use its wall time as a baseline."
  for report in \
    cuda_gpu_kern_sum \
    cuda_gpu_mem_time_sum \
    cuda_gpu_mem_size_sum \
    cuda_api_sum \
    openacc_sum
  do
    csv=$ARCHIVE_DIR/$report.csv
    if [ -f "$csv" ]; then
      echo
      echo "[$report: first 15 rows]"
      sed -n '1,16p' "$csv"
    fi
  done
  if [ -f "$ARCHIVE_DIR/cuda_api_sum.csv" ]; then
    echo
    echo "[cuda_api_sum: allocation/free rows]"
    awk 'NR == 1 || tolower($0) ~ /alloc|malloc|free/' \
      "$ARCHIVE_DIR/cuda_api_sum.csv"
  fi
} > "$SUMMARY"

cd "$ROOT_DIR"
python3 ./tools/check_tddft_result.py check "$TDDFT_OUT" \
  --err "$TDDFT_ERR" > "$ARCHIVE_DIR/check.txt"
python3 ./tools/check_tddft_result.py compare "$TDDFT_OUT" \
  --test-err "$TDDFT_ERR" > "$ARCHIVE_DIR/compare.txt"

cat "$ARCHIVE_DIR/check.txt"
cat "$ARCHIVE_DIR/compare.txt"
echo "Nsight archive: $ARCHIVE_DIR"
echo "Condensed summary: $SUMMARY"
echo "This diagnostic run is not a wall-time baseline."
