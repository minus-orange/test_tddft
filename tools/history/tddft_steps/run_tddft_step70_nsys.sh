#!/bin/sh
set -eu

# Re-profile the restored current Step 67 source. Diagnostic trace only.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP70_STEP67_NSYS_01}
ARCHIVE_DIR=$ROOT_DIR/run/nsys_archives/$LABEL

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
if [ -e "$ARCHIVE_DIR" ]; then
  echo "ERROR: Nsight archive already exists: $ARCHIVE_DIR" >&2
  exit 1
fi

FPSEID_FRPRMN_DIAGNOSTIC=0 \
TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
  "$ROOT_DIR/tools/build_nvhpc.sh"

DRIVER_LOG=$ROOT_DIR/run/step70_nsys_driver.log
if ! LABEL="$LABEL" NSYS_TRACE=cuda,openacc,nvtx,osrt,mpi \
    "$ROOT_DIR/tools/profile_tddft_nsys.sh" "$RUN_DIR" \
    > "$DRIVER_LOG" 2>&1; then
  tail -n 80 "$DRIVER_LOG"
  exit 1
fi

echo
echo "FPSEID21 STEP70 NSIGHT SYSTEMS SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "label=$LABEL"
echo "source_diagnostic=OFF nsys_trace=ON check=PASS compare=PASS"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($0 ~ /time_step_total|frprmn[[:space:]]|tmevl_total/) {
    print
  }
' "$ARCHIVE_DIR/tddft.out"

for report in cuda_gpu_kern_sum cuda_gpu_mem_time_sum \
  cuda_gpu_mem_size_sum cuda_api_sum openacc_sum osrt_sum mpi_sum
do
  csv=$ARCHIVE_DIR/$report.csv
  if [ -f "$csv" ]; then
    echo
    echo "[$report: first 10 rows]"
    sed -n '1,11p' "$csv"
  fi
done

if [ -f "$ARCHIVE_DIR/cuda_api_sum.csv" ]; then
  echo
  echo "[cuda_api_sum: allocation/free rows]"
  awk 'NR == 1 || tolower($0) ~ /alloc|malloc|free/' \
    "$ARCHIVE_DIR/cuda_api_sum.csv"
fi
echo
echo "Diagnostic trace only; do not use its wall time as a baseline."
