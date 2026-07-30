#!/bin/sh
set -eu

# Split current NONLOCF coefficient kinetic/current plus MPI on the A100.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP111_STEP107_KINETIC_SPLIT_01}

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
echo "FPSEID21 STEP111 NONLOCF KINETIC/CURRENT SPLIT SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "source_baseline=c46cfa9"
echo "label=$LABEL"
echo "diagnostic=ON check=PASS compare=PASS"
echo "official_step107_median_sec=63.2135219574"
grep 'steps took' "$ARCHIVE_DIR/tddft.out" | tail -n 1
echo "FPSEID_NONLOCF_KINETIC_SPLIT_BEGIN"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($2 ~ /^(nonlocf_kinetic_mpi|nonlocf_k_gprep|nonlocf_k_reduce|nonlocf_k_comm|nonlocf_eed_gprep|nonlocf_eed_reduce|nonlocf_eed_comm|nonlocf_ylm_radius)$/) {
    print
    count[$2]=$3
    value[$2]=$4
  }
  END {
    parent=value["nonlocf_kinetic_mpi"]
    classified=value["nonlocf_k_gprep"]
    classified+=value["nonlocf_k_reduce"]
    classified+=value["nonlocf_k_comm"]
    classified+=value["nonlocf_eed_gprep"]
    classified+=value["nonlocf_eed_reduce"]
    classified+=value["nonlocf_eed_comm"]
    classified+=value["nonlocf_ylm_radius"]
    gap=parent-classified
    if (parent <= 0.0) {
      print "ERROR: NONLOCF kinetic parent timer is missing." > "/dev/stderr"
      exit 2
    }
    if (count["nonlocf_kinetic_mpi"] != 202 ||
        count["nonlocf_k_gprep"] != 202 ||
        count["nonlocf_k_reduce"] != 202 ||
        count["nonlocf_k_comm"] != 202 ||
        count["nonlocf_eed_gprep"] != 202 ||
        count["nonlocf_eed_reduce"] != 202 ||
        count["nonlocf_eed_comm"] != 202 ||
        count["nonlocf_ylm_radius"] != 202) {
      print "ERROR: unexpected NONLOCF kinetic timer counts." > "/dev/stderr"
      exit 3
    }
    printf "derived classified_sec %.6f\n", classified
    printf "derived unclassified_gap_sec %.6f\n", gap
    printf "derived k_gprep_pct %.3f\n",
           100.0*value["nonlocf_k_gprep"]/parent
    printf "derived k_reduce_pct %.3f\n",
           100.0*value["nonlocf_k_reduce"]/parent
    printf "derived k_comm_pct %.3f\n",
           100.0*value["nonlocf_k_comm"]/parent
    printf "derived eed_gprep_pct %.3f\n",
           100.0*value["nonlocf_eed_gprep"]/parent
    printf "derived eed_reduce_pct %.3f\n",
           100.0*value["nonlocf_eed_reduce"]/parent
    printf "derived eed_comm_pct %.3f\n",
           100.0*value["nonlocf_eed_comm"]/parent
    printf "derived ylm_radius_pct %.3f\n",
           100.0*value["nonlocf_ylm_radius"]/parent
    printf "derived unclassified_gap_pct %.3f\n", 100.0*gap/parent
  }
' "$ARCHIVE_DIR/tddft.out"
echo "FPSEID_NONLOCF_KINETIC_SPLIT_END"
echo "Diagnostic wall only; do not use it as a performance baseline."
