#!/bin/sh
set -eu

# Screen three isolated NVHPC flag changes against a same-session baseline.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
MPI_FC=${MPI_FC:-mpifort}
NVFORTRAN=${NVFORTRAN:-nvfortran}
OFFICIAL_MEDIAN=63.2135219574
BASE_FLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays"

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

CURRENT_REVISION=$(git rev-parse HEAD)
summary_lines=
screen_baseline=

run_variant() {
  tag=$1
  flags=$2
  effective_flags="$flags -gpu=mem:separate:pinnedalloc"
  label=nvhpc_cufft_1rank_02_STEP113_FLAGS_${tag}_01
  archive_dir=$ROOT_DIR/run/tddft_archives/$label

  if [ -e "$archive_dir" ]; then
    metadata=$archive_dir/step113.env
    if [ ! -f "$metadata" ]; then
      echo "ERROR: existing archive lacks Step 113 metadata: $label" >&2
      exit 1
    fi
    archived_revision=$(sed -n 's/^revision=//p' "$metadata")
    archived_flags=$(sed -n 's/^flags=//p' "$metadata")
    if [ "$archived_revision" != "$CURRENT_REVISION" ] ||
       [ "$archived_flags" != "$effective_flags" ]; then
      echo "ERROR: existing archive provenance mismatch: $label" >&2
      exit 1
    fi
    echo
    echo "STEP113 reusing validated archive variant=$tag"
  else
    echo
    echo "STEP113 building variant=$tag"
    FPSEID_FRPRMN_DIAGNOSTIC=0 \
    TDDFT_FFLAGS="$flags" \
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
    LABEL="$label" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
      TDDFT_ERR=Si111-H_tm.err \
      "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

    {
      echo "revision=$CURRENT_REVISION"
      echo "flags=$effective_flags"
    } > "$archive_dir/step113.env"
  fi

  python3 "$SCRIPT_DIR/check_tddft_result.py" check \
    "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null
  python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
    "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null

  strict=PASS
  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
      --expected-steps 100 --strict >/dev/null; then
    strict=FAIL
  fi

  wall=$(awk '
    /steps took/ {
      value=$(NF-1)
      gsub(/[dD]/,"E",value)
    }
    END { printf "%.10f", value+0.0 }
  ' "$archive_dir/tddft.out")
  if [ "$tag" = BASELINE ]; then
    screen_baseline=$wall
  fi
  screen_delta=$(awk -v wall="$wall" -v base="$screen_baseline" \
    'BEGIN { printf "%.10f", wall-base }')
  screen_pct=$(awk -v wall="$wall" -v base="$screen_baseline" \
    'BEGIN { printf "%.6f", 100.0*(wall-base)/base }')
  official_pct=$(awk -v wall="$wall" -v base="$OFFICIAL_MEDIAN" \
    'BEGIN { printf "%.6f", 100.0*(wall-base)/base }')
  summary_lines="${summary_lines}
$tag $wall $screen_delta $screen_pct $official_pct PASS PASS $strict"
}

run_variant BASELINE "$BASE_FLAGS"
run_variant O3 "-O3 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays"
run_variant IPA "$BASE_FLAGS -Mipa=fast,inline"
run_variant FASTMATH \
  "-O2 -acc -gpu=cc80,fastmath -mp -Msave -Mlarge_arrays"

compiler=$("$NVFORTRAN" -V 2>&1 |
  sed -n '/[^[:space:]]/{p;q;}' || true)
gpu=$(nvidia-smi --query-gpu=name,driver_version \
  --format=csv,noheader 2>/dev/null | sed -n '1p' || true)

echo
echo "FPSEID21 STEP113 NVHPC FLAG SCREEN SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "source_baseline=c46cfa9"
echo "official_step107_median_sec=$OFFICIAL_MEDIAN"
echo "diagnostic=OFF gpu=A100 mpi_ranks=1 steps=100"
echo "compiler=$compiler"
echo "device=$gpu"
echo "FPSEID_FLAGS_BEGIN"
echo "variant wall_sec vs_screen_sec vs_screen_pct vs_official_pct check relaxed strict"
printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
echo "FPSEID_FLAGS_END"
echo "BASELINE_FLAGS=$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
echo "O3_FLAGS=-O3 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc"
echo "IPA_FLAGS=$BASE_FLAGS -Mipa=fast,inline -gpu=mem:separate:pinnedalloc"
echo "FASTMATH_FLAGS=-O2 -acc -gpu=cc80,fastmath -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc"
echo "One-run screening only; no result here replaces the official baseline."
