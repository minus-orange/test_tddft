#!/bin/sh
set -eu

# Print current energy children from the existing Step 87 archive.
# This performs no build or run.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP87_STEP86_HLOCAL_01}
OUTPUT=${TDDFT_OUTPUT:-"$ROOT_DIR/run/tddft_archives/$LABEL/tddft.out"}

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: Step 87 archive output is missing: $OUTPUT" >&2
  exit 1
fi

echo "FPSEID21 STEP87 EXISTING ARCHIVE ENERGY DETAIL"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 87 archive."

awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active {
    value[$2]=$4
  }
  END {
    print ""
    print "[Current energy hierarchy: seconds]"
    energy[1]="frprmn_energy_diag"
    energy[2]="frprmn_energy_vg_build"
    energy[3]="frprmn_energy_efield"
    energy[4]="frprmn_energy_expect"
    energy[5]="energy_diag_hlocal"
    energy[6]="energy_diag_nonloc"
    energy[7]="energy_diag_dot"
    energy[8]="energy_diag_ee_comm"
    energy[9]="energy_offdiag_total"
    energy[10]="offdiag_hlocal"
    energy[11]="offdiag_nonloc"
    energy[12]="offdiag_dot"
    energy[13]="offdiag_comm_copy"
    energy[14]="offdiag_gather_output"
    for (i=1; i<=14; i++)
      printf "%-30s %10.6f\n", energy[i], value[energy[i]]

    diag=value["energy_diag_hlocal"]+value["energy_diag_nonloc"] \
      +value["energy_diag_dot"]+value["energy_diag_ee_comm"]
    offdiag=value["offdiag_hlocal"]+value["offdiag_nonloc"] \
      +value["offdiag_dot"]+value["offdiag_comm_copy"] \
      +value["offdiag_gather_output"]
    printf "%-30s %10.6f\n", "derived_diag_gap",
      value["frprmn_energy_expect"]-diag-value["energy_offdiag_total"]
    printf "%-30s %10.6f\n", "derived_offdiag_gap",
      value["energy_offdiag_total"]-offdiag
    printf "%-30s %10.6f\n", "derived_energy_nonloc_total",
      value["energy_diag_nonloc"]+value["offdiag_nonloc"]
  }
' "$OUTPUT"
