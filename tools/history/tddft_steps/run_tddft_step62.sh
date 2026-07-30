#!/bin/sh
set -eu

# Test the bounded Step 62 OpenACC hypothesis with diagnostics off.
# Use 01 first; after it passes, use 02-03 to collect both remaining runs.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
RUN_SET=${1:-01}

case "$RUN_SET" in
  01) RUN_LIST=01 ;;
  02-03) RUN_LIST="02 03" ;;
  *)
    echo "ERROR: run set must be 01 or 02-03." >&2
    exit 1
    ;;
esac

cd "$ROOT_DIR"
if [ "$(git branch --show-current)" != tddft-openacc-residency ]; then
  echo "ERROR: checkout tddft-openacc-residency first." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked worktree or index is not clean." >&2
  exit 1
fi
set -- $(git rev-list --left-right --count \
  origin/tddft-openacc-residency...HEAD)
if [ "$1" != 0 ] || [ "$2" != 0 ]; then
  echo "ERROR: local branch and origin are not synchronized." >&2
  exit 1
fi
if [ ! -f "$RUN_DIR/Si111-H_tm.in_100steps" ]; then
  echo "ERROR: prepared 100-step run directory is missing: $RUN_DIR" >&2
  exit 1
fi
for run_no in $RUN_LIST
do
  label=nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_$run_no
  if [ -e "$ROOT_DIR/run/tddft_archives/$label" ]; then
    echo "ERROR: archive label already exists: $label" >&2
    exit 1
  fi
done

FPSEID_FRPRMN_DIAGNOSTIC=0 \
TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
  "$ROOT_DIR/tools/build_nvhpc.sh"

for run_no in $RUN_LIST
do
  label=nvhpc_cufft_1rank_02_STEP62_SKIP_HOST_COEFCP_$run_no
  cd "$RUN_DIR"
  ulimit -s unlimited 2>/dev/null || true
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=512M
  export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
  mpirun -np 1 "$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" \
    < Si111-H_tm.in_100steps \
    > Si111-H_tm.out_100steps \
    2> Si111-H_tm.err

  cd "$ROOT_DIR"
  LABEL="$label" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
    TDDFT_ERR=Si111-H_tm.err \
    "$ROOT_DIR/tools/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

  archive_dir=$ROOT_DIR/run/tddft_archives/$label
  python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
    "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" >/dev/null
  python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
    "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" >/dev/null

  echo
  echo "FPSEID21 STEP62 PERFORMANCE SUMMARY"
  echo "revision=$(git rev-parse HEAD)"
  echo "label=$label"
  echo "diagnostic=OFF check=PASS compare=PASS"
  grep 'steps took' "$archive_dir/tddft.out" | tail -n 1
  awk '
    /FPSEID_PROFILE_BEGIN/ { active=1; next }
    /FPSEID_PROFILE_END/ { active=0 }
    active && ($0 ~ /time_step_total|frprmn[[:space:]]|tmevl_total|s2_nonlocal|exnlp_gemm_dot/) {
      print
    }
  ' "$archive_dir/tddft.out"
done
