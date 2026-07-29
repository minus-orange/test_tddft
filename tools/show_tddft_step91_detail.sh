#!/bin/sh
set -eu

# Print the transfer/synchronization detail already stored by Step 91.
# This helper does not build, profile, or rerun TDDFT.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP91_STEP86_NSYS_01}
ARCHIVE_DIR=$ROOT_DIR/run/nsys_archives/$LABEL
OPENACC_CSV=$ARCHIVE_DIR/openacc_sum.csv
CUDA_API_CSV=$ARCHIVE_DIR/cuda_api_sum.csv

if [ ! -f "$OPENACC_CSV" ] || [ ! -f "$CUDA_API_CSV" ]; then
  echo "ERROR: Step 91 CSV reports are missing: $ARCHIVE_DIR" >&2
  exit 1
fi

echo "FPSEID21 STEP91 EXISTING ARCHIVE TRANSFER/SYNC DETAIL"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 91 archive."
echo
echo "[OpenACC TMEVL update/wait rows]"
awk 'NR == 1 || ($0 ~ /tmevl10_Avec_v4.f/ && $0 ~ /Update|Wait/)' \
  "$OPENACC_CSV"
echo
echo "[CUDA synchronization/copy rows]"
awk 'NR == 1 || $0 ~ /cuStreamSynchronize|cudaEventSynchronize|cudaMemcpy/' \
  "$CUDA_API_CSV"
echo
echo "[Step 70 -> Step 91 comparison: seconds]"
echo "metric                       step70          step91          delta"
printf "%-28s %12.9f %12.9f %+12.9f\n" \
  "H2D+D2H" 3.230806864 2.961480313 -0.269326551
printf "%-28s %12.9f %12.9f %+12.9f\n" \
  "stream+event sync" 17.372092065 17.235587864 -0.136504201
printf "%-28s %12.9f %12.9f %+12.9f\n" \
  "fused nonlocal kernel" 8.247974033 8.200543838 -0.047430195
printf "%-28s %12.9f %12.9f %+12.9f\n" \
  "VPJ kernel" 1.574436754 1.559553328 -0.014883426
echo "Trace/API rows overlap; do not add them into an application wall model."
