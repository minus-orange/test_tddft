#!/bin/sh
set -eu

# Print the next-candidate envelopes from the existing Step 83 archive.
# This performs no build or run.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP83_STEP82_VRHO_01}
OUTPUT=${TDDFT_OUTPUT:-"$ROOT_DIR/run/tddft_archives/$LABEL/tddft.out"}

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: Step 83 archive output is missing: $OUTPUT" >&2
  exit 1
fi

echo "FPSEID21 STEP83 EXISTING ARCHIVE NEXT-CANDIDATE DETAIL"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 83 archive."

awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active {
    value[$2]=$4
  }
  END {
    print ""
    print "[Current broad envelopes: seconds]"
    broad[1]="frprmn"
    broad[2]="tmevl_total"
    broad[3]="frprmn_part1to5"
    broad[4]="frprmn_extau_prepare"
    broad[5]="frprmn_vrho_mix"
    broad[6]="frprmn_energy_diag"
    for (i=1; i<=6; i++)
      printf "%-30s %10.6f\n", broad[i], value[broad[i]]
    printf "%-30s %10.6f\n", "derived_frprmn_residual",
      value["frprmn"]-value["tmevl_total"]

    print ""
    print "[Current energy children: seconds]"
    energy[1]="frprmn_energy_diag"
    energy[2]="frprmn_energy_vg_build"
    energy[3]="frprmn_energy_efield"
    energy[4]="frprmn_energy_expect"
    energy[5]="energy_diag_hlocal"
    energy[6]="energy_diag_nonloc"
    energy[7]="energy_diag_dot"
    energy[8]="energy_offdiag_total"
    energy[9]="offdiag_hlocal"
    energy[10]="offdiag_nonloc"
    energy[11]="offdiag_dot"
    for (i=1; i<=11; i++)
      printf "%-30s %10.6f\n", energy[i], value[energy[i]]
  }
' "$OUTPUT"
