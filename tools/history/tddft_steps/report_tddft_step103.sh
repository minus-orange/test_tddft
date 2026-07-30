#!/bin/sh
set -eu

# Print the kinetic-phase ceiling from the existing Step 100 archive.
# This performs no build or TDDFT rerun.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP100_STEP99_CURRENT_PROFILE_01}
OUTPUT=${TDDFT_OUTPUT:-"$ROOT_DIR/run/tddft_archives/$LABEL/tddft.out"}

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: Step 100 archive output is missing: $OUTPUT" >&2
  exit 1
fi

echo "FPSEID21 STEP103 EXISTING-ARCHIVE KINETIC DETAIL"
echo "source_baseline=d021066"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 100 archive."
echo "FPSEID_STEP103_DETAIL_BEGIN"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active {
    count[$2]=$3
    value[$2]=$4
  }
  END {
    name[1]="time_step_total"
    name[2]="tmevl_total"
    name[3]="tmevl_exkin"
    name[4]="exkin_acc_kernel"
    name[5]="tmevl_s2"
    name[6]="s2_fft_local"
    name[7]="fft_wrapper"
    for (i=1; i<=7; i++)
      printf "%-20s %7d %10.6f\n", name[i], count[name[i]],
        value[name[i]]
    printf "%-20s %18.6f\n", "derived_exkin_gap",
      value["tmevl_exkin"]-value["exkin_acc_kernel"]
  }
' "$OUTPUT"
echo "FPSEID_STEP103_DETAIL_END"
echo "Step 100 diagnostic wall is not a performance baseline."
