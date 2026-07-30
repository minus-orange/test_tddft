#!/bin/sh
set -eu

# Recheck and summarize an already archived Step 95 diagnostic run.
# The default revision identifies the original run whose summary failed only
# because its awk implementation reserves "split" as a function name.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP95_STEP86_LOCPOTF_SPLIT_01}
REVISION=${REVISION:-6952f5403719fe19f64033dd0e3292ddff3f2a3e}
ARCHIVE_DIR=$ROOT_DIR/run/tddft_archives/$LABEL

if [ ! -f "$ARCHIVE_DIR/tddft.out" ]; then
  echo "ERROR: archived Step 95 output is missing: $ARCHIVE_DIR/tddft.out" >&2
  exit 1
fi
if [ ! -f "$ARCHIVE_DIR/tddft.err" ]; then
  echo "ERROR: archived Step 95 stderr is missing: $ARCHIVE_DIR/tddft.err" >&2
  exit 1
fi

python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
  "$ARCHIVE_DIR/tddft.out" --err "$ARCHIVE_DIR/tddft.err" >/dev/null
python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
  "$ARCHIVE_DIR/tddft.out" --test-err "$ARCHIVE_DIR/tddft.err" >/dev/null

echo
echo "FPSEID21 STEP95 ELECTF LOCPOTF SPLIT SUMMARY"
echo "revision=$REVISION"
echo "source_baseline=9dd8c20"
echo "label=$LABEL"
echo "diagnostic=ON check=PASS compare=PASS"
echo "official_step86_median_sec=66.5019950867"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($2 ~ /^(time_step_total|electf_force|electf_locpotf_total|locpotf_local_mpi|locpotf_ewald|locpotf_local_energy|locpotf_xc|locpotf_hartree)$/) {
    print
    value[$2]=$4
  }
  END {
    total=value["electf_locpotf_total"]
    local=value["locpotf_local_mpi"]
    remainder=total-local
    child_total=value["locpotf_ewald"]+value["locpotf_local_energy"]+value["locpotf_xc"]+value["locpotf_hartree"]
    gap=remainder-child_total
    printf "derived locpotf_remainder_sec %.6f\n", remainder
    printf "derived remainder_split_sec %.6f\n", child_total
    printf "derived remainder_gap_sec %.6f\n", gap
    if (remainder > 0.0) {
      printf "derived ewald_pct %.3f\n", 100.0*value["locpotf_ewald"]/remainder
      printf "derived local_energy_pct %.3f\n", 100.0*value["locpotf_local_energy"]/remainder
      printf "derived xc_pct %.3f\n", 100.0*value["locpotf_xc"]/remainder
      printf "derived hartree_pct %.3f\n", 100.0*value["locpotf_hartree"]/remainder
      printf "derived gap_pct %.3f\n", 100.0*gap/remainder
    }
  }
' "$ARCHIVE_DIR/tddft.out"
echo "Percentages use the LOCPOTF remainder outside local_mpi."
echo "Diagnostic wall only; do not use it as a performance baseline."
