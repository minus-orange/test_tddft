#!/bin/sh
set -eu

# Print actionable S2/nonlocal detail from the existing Step 100 archive.
# This performs no build or TDDFT rerun.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP100_STEP99_CURRENT_PROFILE_01}
OUTPUT=${TDDFT_OUTPUT:-"$ROOT_DIR/run/tddft_archives/$LABEL/tddft.out"}

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: Step 100 archive output is missing: $OUTPUT" >&2
  exit 1
fi

echo "FPSEID21 STEP101 EXISTING-ARCHIVE S2 DETAIL"
echo "source_baseline=6b4099f"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 100 archive."
echo "FPSEID_STEP101_DETAIL_BEGIN"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active {
    count[$2]=$3
    value[$2]=$4
  }
  END {
    name[1]="tmevl_s2"
    name[2]="s2_nonlocal"
    name[3]="s2_nonlocal_make"
    name[4]="s2_nonlocal_gemm"
    name[5]="exnlp_gemm_data"
    name[6]="exnlp_gemm_dot"
    name[7]="exnlp_work1_enter"
    name[8]="exnlp_meta_enter"
    name[9]="s2_fft_local"
    name[10]="s2_acc_update"
    name[11]="s2_acc_kernel"
    name[12]="s2_zero_rho2"
    name[13]="s2_scatter_p"
    name[14]="s2_vg_build"
    name[15]="s2_local_multiply"
    name[16]="s2_gather_p"
    for (i=1; i<=16; i++)
      printf "%-24s %7d %10.6f\n", name[i], count[name[i]],
        value[name[i]]

    reuse_diag=value["s2_nonlocal"]-value["s2_nonlocal_make"] \
      -value["s2_nonlocal_gemm"]
    local_children=value["s2_zero_rho2"]+value["s2_scatter_p"] \
      +value["s2_vg_build"]+value["s2_local_multiply"] \
      +value["s2_gather_p"]
    printf "%-24s %18.6f\n", "derived_reuse_diag_sec", reuse_diag
    printf "%-24s %18.6f\n", "derived_s2_local_gap_sec",
      value["s2_fft_local"]-local_children
  }
' "$OUTPUT"
echo "FPSEID_STEP101_DETAIL_END"
echo "Reuse diagnostic time is absent from diagnostic-OFF performance runs."
