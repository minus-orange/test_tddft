#!/bin/sh
set -eu

# Confirm the VRHO seed/control change on the accepted Step 82 source.
# Diagnostic only; its wall time is not a performance baseline.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP83_STEP82_VRHO_01}

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
echo "FPSEID21 STEP83 CURRENT VRHO SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "source_baseline=2b7f5ba"
echo "label=$LABEL"
echo "diagnostic=ON check=PASS compare=PASS"
echo "official_step82_median_sec=66.6539101601"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($2 ~ /^(time_step_total|frprmn|tmevl_total|frprmn_vrho_mix|frprmn_vrho_vofrho|frprmn_vrho_smooth_fft|frprmn_vrho_mix_control|frprmn_vrho_seed_ctrl|frprmn_vrho_predict_ctrl|frprmn_vrho_correct_ctrl|frprmn_vrho_interp|frprmn_vrho_converge|frprmn_vrho_coef_restore)$/) {
    print
    value[$2]=$4
  }
  END {
    parent_gap=value["frprmn_vrho_mix"] \
      -value["frprmn_vrho_vofrho"] \
      -value["frprmn_vrho_smooth_fft"] \
      -value["frprmn_vrho_mix_control"]
    control_gap=value["frprmn_vrho_mix_control"] \
      -value["frprmn_vrho_seed_ctrl"] \
      -value["frprmn_vrho_predict_ctrl"] \
      -value["frprmn_vrho_correct_ctrl"]
    corrector_gap=value["frprmn_vrho_correct_ctrl"] \
      -value["frprmn_vrho_interp"] \
      -value["frprmn_vrho_converge"] \
      -value["frprmn_vrho_coef_restore"]
    printf "derived vrho_parent_gap %.6f\n", parent_gap
    printf "derived vrho_control_gap %.6f\n", control_gap
    printf "derived vrho_corrector_gap %.6f\n", corrector_gap
  }
' "$ARCHIVE_DIR/tddft.out"
echo "Diagnostic wall only; do not use it as a performance baseline."
