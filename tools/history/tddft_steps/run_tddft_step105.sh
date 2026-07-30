#!/bin/sh
set -eu

# Split current-source ELECTF NONLOCF into setup, kinetic/MPI, GETYLM,
# SEPPOTF, finalization, and an unclassified gap.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP105_STEP102_NONLOCF_SPLIT_01}

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
if [ -e "$ROOT_DIR/run/tddft_archives/$LABEL" ]; then
  echo "ERROR: archive label already exists: $LABEL" >&2
  exit 1
fi

FPSEID_FRPRMN_DIAGNOSTIC=1 \
TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
  "$ROOT_DIR/tools/build_nvhpc.sh"

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
LABEL="$LABEL" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
  TDDFT_ERR=Si111-H_tm.err \
  "$ROOT_DIR/tools/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

ARCHIVE_DIR=$ROOT_DIR/run/tddft_archives/$LABEL
python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
  "$ARCHIVE_DIR/tddft.out" --err "$ARCHIVE_DIR/tddft.err" >/dev/null
python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
  "$ARCHIVE_DIR/tddft.out" --test-err "$ARCHIVE_DIR/tddft.err" >/dev/null

echo
echo "FPSEID21 STEP105 ELECTF NONLOCF SPLIT SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "source_baseline=d021066"
echo "label=$LABEL"
echo "diagnostic=ON check=PASS compare=PASS"
echo "official_step102_median_sec=63.8388190269"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
echo "FPSEID_NONLOCF_SPLIT_BEGIN"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($2 ~ /^(electf_force|electf_locpotf_total|electf_nonlocf_total|nonlocf_setup|nonlocf_kinetic_mpi|nonlocf_getylm|nonlocf_seppotf|nonlocf_finalize)$/) {
    print
    count[$2]=$3
    value[$2]=$4
  }
  END {
    total=value["electf_nonlocf_total"]
    child_total=value["nonlocf_setup"]
    child_total+=value["nonlocf_kinetic_mpi"]
    child_total+=value["nonlocf_getylm"]
    child_total+=value["nonlocf_seppotf"]
    child_total+=value["nonlocf_finalize"]
    gap=total-child_total
    if (total <= 0.0) {
      print "ERROR: NONLOCF timers are missing." > "/dev/stderr"
      exit 2
    }
    if (count["electf_nonlocf_total"] != 101 ||
        count["nonlocf_setup"] != 101 ||
        count["nonlocf_kinetic_mpi"] != 202 ||
        count["nonlocf_getylm"] != 202 ||
        count["nonlocf_seppotf"] != 202 ||
        count["nonlocf_finalize"] != 101) {
      print "ERROR: unexpected NONLOCF timer counts." > "/dev/stderr"
      exit 3
    }
    printf "derived child_total_sec %.6f\n", child_total
    printf "derived unclassified_gap_sec %.6f\n", gap
    printf "derived setup_pct %.3f\n", 100.0*value["nonlocf_setup"]/total
    printf "derived kinetic_mpi_pct %.3f\n",
           100.0*value["nonlocf_kinetic_mpi"]/total
    printf "derived getylm_pct %.3f\n", 100.0*value["nonlocf_getylm"]/total
    printf "derived seppotf_pct %.3f\n", 100.0*value["nonlocf_seppotf"]/total
    printf "derived finalize_pct %.3f\n",
           100.0*value["nonlocf_finalize"]/total
    printf "derived unclassified_gap_pct %.3f\n", 100.0*gap/total
  }
' "$ARCHIVE_DIR/tddft.out"
echo "FPSEID_NONLOCF_SPLIT_END"
echo "Diagnostic wall only; do not use it as a performance baseline."
