#!/bin/sh
set -eu

# Combine existing Step 88 source timers with Step 91 source-attributed
# OpenACC rows.  This helper does not build or rerun TDDFT.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
TIMER_LABEL=${TIMER_LABEL:-nvhpc_cufft_1rank_02_STEP88_STEP86_NONLOC_01}
NSYS_LABEL=${NSYS_LABEL:-nvhpc_cufft_1rank_02_STEP91_STEP86_NSYS_01}
TIMER_OUT=$ROOT_DIR/run/tddft_archives/$TIMER_LABEL/tddft.out
OPENACC_CSV=$ROOT_DIR/run/nsys_archives/$NSYS_LABEL/openacc_sum.csv

if [ ! -f "$TIMER_OUT" ]; then
  echo "ERROR: Step 88 output is missing: $TIMER_OUT" >&2
  exit 1
fi
if [ ! -f "$OPENACC_CSV" ]; then
  echo "ERROR: Step 91 OpenACC report is missing: $OPENACC_CSV" >&2
  exit 1
fi

echo "FPSEID21 CURRENT NONLOCAL HOST/UPDATE/KERNEL DETAIL"
echo "timer_label=$TIMER_LABEL"
echo "nsys_label=$NSYS_LABEL"
echo "No build or rerun; values come from existing Step 88/91 archives."
echo
echo "[Step 88 current-source timers: seconds]"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($2 ~ /^(s2_nonlocal|s2_nonlocal_make|s2_nonlocal_gemm|exnlp_gemm_data|exnlp_gemm_dot|exnlp_work1_enter|exnlp_meta_enter)$/) {
    print
  }
' "$TIMER_OUT"
echo
echo "[Step 91 source-attributed OpenACC rows]"
awk 'NR == 1 || $0 ~ /tmevl10_Avec_v4.f:(1930|1933|2405)/' \
  "$OPENACC_CSV"
echo
echo "Update rows include their nested Wait rows; do not add them together."
