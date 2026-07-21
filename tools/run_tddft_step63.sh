#!/bin/sh
set -eu

# Re-measure the current accepted Step 62 FRPRMN host envelopes.
# This diagnostic changes no equations or OpenACC ownership.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP63_CURRENT_FRPRMN_01}

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
  "$SCRIPT_DIR/build_nvhpc.sh"

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
  "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

ARCHIVE_DIR=$ROOT_DIR/run/tddft_archives/$LABEL
python3 "$SCRIPT_DIR/check_tddft_result.py" check \
  "$ARCHIVE_DIR/tddft.out" --err "$ARCHIVE_DIR/tddft.err" >/dev/null
python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
  "$ARCHIVE_DIR/tddft.out" --test-err "$ARCHIVE_DIR/tddft.err" >/dev/null

echo
echo "FPSEID21 STEP63 CURRENT FRPRMN SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "label=$LABEL"
echo "diagnostic=ON check=PASS compare=PASS"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($0 ~ /time_step_total|frprmn[[:space:]]|tmevl_total|frprmn_rhoofk|frprmn_rhoget|frprmn_coef_sync|frprmn_coef_setup|frprmn_gdump_prepare|frprmn_part1to5|frprmn_extau_prepare|frprmn_vloc_prepare|frprmn_vrho_mix|frprmn_energy_diag/) { print }
' "$ARCHIVE_DIR/tddft.out"
echo "Current accepted source; diagnostic wall is not a baseline."
