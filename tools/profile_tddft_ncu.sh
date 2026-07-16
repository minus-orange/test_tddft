#!/bin/sh
set -eu

# Profile one FPSEID21 TDDFT GPU kernel with Nsight Compute.
# This is a resource/occupancy diagnostic and is not a wall-time baseline.
#
# Usage:
#   LABEL=nvhpc_cufft_1rank_02_STEP39_FUSED_NCU_01 \
#     ./tools/profile_tddft_ncu.sh ./run/Si111-H_nvhpc
#
# Environment:
#   LABEL             required archive label
#   TDDFT_INPUT       default: Si111-H_tm.in_2steps
#   TDDFT_EXE         default: <repo>/FPSEID21/tddft_2022October/tddft_exe
#   NCU               default: ncu
#   NCU_SET           default: full
#   NCU_KERNEL_NAME   default: regex:exnlp_gemm_body_fused
#   NCU_LAUNCH_COUNT  default: 1
#   NCU_REPLAY_MODE   default: kernel
#   MPIRUN            default: mpirun
#   MPIRUN_FLAGS      default: empty
#   NPROCS            default: 1
#   NCU_ROOT          default: <repo>/run/ncu_archives
#   CUDA_VISIBLE_DEVICES default: 0
#   DRY_RUN           set to 1 to print the resolved run without executing it

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

# Keep application stdout/stderr separate from Nsight Compute diagnostics while
# Nsight Compute follows the MPI launcher and its child process.
if [ "${FPSEID_NCU_TARGET_MODE:-0}" = 1 ]; then
  cd "$FPSEID_NCU_RUN_DIR"
  ulimit -s unlimited 2>/dev/null || true
  # shellcheck disable=SC2086
  "$FPSEID_NCU_MPIRUN" $FPSEID_NCU_MPIRUN_FLAGS \
    -np "$FPSEID_NCU_NPROCS" "$FPSEID_NCU_TDDFT_EXE" \
    < "$FPSEID_NCU_INPUT" \
    > "$FPSEID_NCU_TDDFT_OUT" \
    2> "$FPSEID_NCU_TDDFT_ERR"
  exit
fi

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

TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_2steps}
TDDFT_EXE=${TDDFT_EXE:-"$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"}
NCU=${NCU:-ncu}
NCU_SET=${NCU_SET:-full}
NCU_KERNEL_NAME=${NCU_KERNEL_NAME:-regex:exnlp_gemm_body_fused}
NCU_LAUNCH_COUNT=${NCU_LAUNCH_COUNT:-1}
NCU_REPLAY_MODE=${NCU_REPLAY_MODE:-kernel}
MPIRUN=${MPIRUN:-mpirun}
MPIRUN_FLAGS=${MPIRUN_FLAGS:-}
NPROCS=${NPROCS:-1}
NCU_ROOT=${NCU_ROOT:-"$ROOT_DIR/run/ncu_archives"}
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

ARCHIVE_DIR=$NCU_ROOT/$LABEL
if [ -e "$ARCHIVE_DIR" ]; then
  echo "ERROR: Nsight Compute archive already exists: $ARCHIVE_DIR" >&2
  exit 1
fi

REPORT_BASE=$ARCHIVE_DIR/fused
REPORT_FILE=$REPORT_BASE.ncu-rep
TDDFT_OUT=$ARCHIVE_DIR/tddft.out
TDDFT_ERR=$ARCHIVE_DIR/tddft.err

echo "Nsight Compute TDDFT kernel diagnostic"
echo "  label:        $LABEL"
echo "  run dir:      $RUN_DIR"
echo "  input:        $TDDFT_INPUT"
echo "  executable:   $TDDFT_EXE"
echo "  kernel:       $NCU_KERNEL_NAME"
echo "  set:          $NCU_SET"
echo "  launch count: $NCU_LAUNCH_COUNT"
echo "  replay mode:  $NCU_REPLAY_MODE"
echo "  output:       $ARCHIVE_DIR"

if [ "$DRY_RUN" = 1 ]; then
  echo "  dry run:      yes"
  exit 0
fi
if ! command -v "$NCU" >/dev/null 2>&1; then
  echo "ERROR: Nsight Compute command was not found: $NCU" >&2
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
ncu_version=$($NCU --version 2>&1 || true)

{
  echo "created_at=$created_at"
  echo "label=$LABEL"
  echo "git_revision=$git_revision"
  echo "git_branch=$git_branch"
  echo "run_dir=$RUN_DIR"
  echo "tddft_input=$TDDFT_INPUT"
  echo "tddft_exe=$TDDFT_EXE"
  echo "nprocs=$NPROCS"
  echo "ncu_set=$NCU_SET"
  echo "ncu_kernel_name=$NCU_KERNEL_NAME"
  echo "ncu_launch_count=$NCU_LAUNCH_COUNT"
  echo "ncu_replay_mode=$NCU_REPLAY_MODE"
  echo "omp_num_threads=$OMP_NUM_THREADS"
  echo "omp_stacksize=$OMP_STACKSIZE"
  echo "cuda_visible_devices=$CUDA_VISIBLE_DEVICES"
  echo "ncu_version=$ncu_version"
} > "$ARCHIVE_DIR/manifest.env"

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -q > "$ARCHIVE_DIR/nvidia-smi-q.txt" 2>&1 || true
fi

export FPSEID_NCU_TARGET_MODE=1
export FPSEID_NCU_RUN_DIR=$RUN_DIR
export FPSEID_NCU_MPIRUN=$MPIRUN
export FPSEID_NCU_MPIRUN_FLAGS=$MPIRUN_FLAGS
export FPSEID_NCU_NPROCS=$NPROCS
export FPSEID_NCU_TDDFT_EXE=$TDDFT_EXE
export FPSEID_NCU_INPUT=$INPUT_PATH
export FPSEID_NCU_TDDFT_OUT=$TDDFT_OUT
export FPSEID_NCU_TDDFT_ERR=$TDDFT_ERR

"$NCU" \
  --target-processes all \
  --set "$NCU_SET" \
  --kernel-name-base function \
  --kernel-name "$NCU_KERNEL_NAME" \
  --launch-count "$NCU_LAUNCH_COUNT" \
  --replay-mode "$NCU_REPLAY_MODE" \
  --force-overwrite \
  --export "$REPORT_BASE" \
  "$SCRIPT_DIR/profile_tddft_ncu.sh" \
  > "$ARCHIVE_DIR/ncu-profile.out" \
  2> "$ARCHIVE_DIR/ncu-profile.err"

unset FPSEID_NCU_TARGET_MODE FPSEID_NCU_RUN_DIR FPSEID_NCU_MPIRUN
unset FPSEID_NCU_MPIRUN_FLAGS FPSEID_NCU_NPROCS
unset FPSEID_NCU_TDDFT_EXE FPSEID_NCU_INPUT
unset FPSEID_NCU_TDDFT_OUT FPSEID_NCU_TDDFT_ERR

if [ ! -f "$REPORT_FILE" ]; then
  echo "ERROR: Nsight Compute report was not produced: $REPORT_FILE" >&2
  exit 1
fi

"$NCU" --import "$REPORT_FILE" --page details \
  > "$ARCHIVE_DIR/fused-details.txt" \
  2> "$ARCHIVE_DIR/ncu-import.err"

SUMMARY=$ARCHIVE_DIR/ncu-summary.txt
{
  echo "FPSEID21 TDDFT Nsight Compute kernel summary"
  echo "label=$LABEL"
  echo "git_revision=$git_revision"
  echo "Diagnostic trace only; do not use its wall time as a baseline."
  echo
  grep -E \
    'Kernel Name|Grid Size|Block Size|Registers Per Thread|Shared Memory|Achieved Occupancy|Theoretical Occupancy|Waves Per SM|Compute \(SM\) Throughput|Memory Throughput|DRAM Throughput|L1/TEX|L2 Cache' \
    "$ARCHIVE_DIR/fused-details.txt" || true
} > "$SUMMARY"

validation_status=0
cd "$ROOT_DIR"
if ! python3 ./tools/check_tddft_result.py check "$TDDFT_OUT" \
    --err "$TDDFT_ERR" \
    > "$ARCHIVE_DIR/check.txt"; then
  validation_status=1
fi

cat "$ARCHIVE_DIR/check.txt"
echo "Nsight Compute archive: $ARCHIVE_DIR"
echo "Kernel summary: $SUMMARY"
echo "This diagnostic run is not a wall-time baseline."
exit "$validation_status"
