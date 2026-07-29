#!/bin/sh
set -eu

# Print existing VRHO and energy child timers from the Step 81 archive.
# This performs no build or run.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP81_STEP80_FRPRMN_01}
ARCHIVE_DIR=$ROOT_DIR/run/tddft_archives/$LABEL
OUTPUT=${TDDFT_OUTPUT:-"$ARCHIVE_DIR/tddft.out"}
MODE=${1:-all}

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: Step 81 archive output is missing: $OUTPUT" >&2
  exit 1
fi

echo "FPSEID21 STEP81 EXISTING ARCHIVE DETAIL"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 81 archive."

awk -v mode="$MODE" '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active {
    value[$2]=$4
    calls[$2]=$3
  }
  END {
    if (mode == "control") {
      print ""
      print "[Step 81 control/count detail]"
      print "label                              calls  total_sec"
      control[1]="frprmn_vrho_mix"
      control[2]="frprmn_vrho_mix_control"
      control[3]="frprmn_vrho_seed_ctrl"
      control[4]="frprmn_vrho_predict_ctrl"
      control[5]="frprmn_vrho_correct_ctrl"
      control[6]="frprmn_vrho_interp"
      control[7]="frprmn_vrho_converge"
      control[8]="frprmn_vrho_coef_restore"
      control[9]="frprmn_energy_diag"
      control[10]="frprmn_energy_efield"
      for (i=1; i<=10; i++)
        printf "%-33s %5d %10.6f\n", control[i],
          calls[control[i]], value[control[i]]
      exit
    }
    print ""
    print "[VRHO detail: seconds]"
    vrho[1]="frprmn_vrho_mix"
    vrho[2]="frprmn_vrho_vofrho"
    vrho[3]="frprmn_vrho_smooth_fft"
    vrho[4]="frprmn_vrho_mix_control"
    vrho[5]="vofrho_xc"
    vrho[6]="vofrho_fft"
    vrho[7]="vofrho_hartree_zero"
    vrho[8]="vofrho_hartree_build"
    vrho[9]="vofrho_hartree_add"
    for (i=1; i<=9; i++)
      printf "%-30s %10.6f\n", vrho[i], value[vrho[i]]
    printf "%-30s %10.6f\n", "derived_vofrho_other",
      value["frprmn_vrho_vofrho"]-value["vofrho_xc"] \
      -value["vofrho_fft"]-value["vofrho_hartree_zero"] \
      -value["vofrho_hartree_build"]-value["vofrho_hartree_add"]

    print ""
    print "[energy detail: seconds]"
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
    printf "%-30s %10.6f\n", "derived_energy_other",
      value["frprmn_energy_diag"]-value["frprmn_energy_vg_build"] \
      -value["frprmn_energy_efield"]-value["frprmn_energy_expect"]
    printf "%-30s %10.6f\n", "derived_expect_other",
      value["frprmn_energy_expect"]-value["energy_diag_hlocal"] \
      -value["energy_diag_nonloc"]-value["energy_diag_dot"] \
      -value["energy_diag_ee_comm"]-value["energy_offdiag_total"]
    printf "%-30s %10.6f\n", "derived_offdiag_other",
      value["energy_offdiag_total"]-value["offdiag_hlocal"] \
      -value["offdiag_nonloc"]-value["offdiag_dot"] \
      -value["offdiag_comm_copy"]-value["offdiag_gather_output"]
  }
' "$OUTPUT"
