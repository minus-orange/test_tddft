#!/bin/sh
set -eu

# Measure the current accepted TDDFT path as an H100 cc90 baseline candidate.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
NVFORTRAN=${NVFORTRAN:-nvfortran}
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}
A100_MEDIAN=63.2135219574
BASE_FLAGS="-O2 -acc -gpu=cc90 -mp -Msave -Mlarge_arrays"
EFFECTIVE_FLAGS="$BASE_FLAGS -gpu=mem:separate:pinnedalloc"

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
case "$GPU_ID" in
  *,*)
    echo "ERROR: expose exactly one H100 through CUDA_VISIBLE_DEVICES." >&2
    exit 1
    ;;
esac

device=$(nvidia-smi -i "$GPU_ID" --query-gpu=name,driver_version \
  --format=csv,noheader 2>/dev/null | sed -n '1p' || true)
case "$device" in
  *H100*) ;;
  *)
    echo
    echo "FPSEID21 STEP115 H100 CC90 BASELINE FAILURE"
    echo "stage=device_preflight"
    echo "requested_gpu=$GPU_ID"
    echo "detected_device=$device"
    echo "Expected an NVIDIA H100; no build or simulation was run."
    exit 1
    ;;
esac

CURRENT_REVISION=$(git rev-parse HEAD)
compiler=$("$NVFORTRAN" -V 2>&1 |
  sed -n '/[^[:space:]]/{p;q;}' || true)
summary_lines=
wall_values=
current_run=
current_label=
current_archive=

print_failure() {
  stage=$1
  echo
  echo "FPSEID21 STEP115 H100 CC90 BASELINE FAILURE"
  echo "revision=$CURRENT_REVISION"
  echo "stage=$stage run=$current_run label=$current_label"
  echo "compiler=$compiler"
  echo "device=$device"
  echo "flags=$EFFECTIVE_FLAGS"
  if [ -n "$summary_lines" ]; then
    echo "FPSEID_STEP115_COMPLETED_BEGIN"
    echo "run wall_sec check relaxed run01_pairwise_strict"
    printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
    echo "FPSEID_STEP115_COMPLETED_END"
  fi
  case "$stage" in
    run|archive)
      error_file=$RUN_DIR/Si111-H_tm.err
      ;;
    check|relaxed_compare)
      error_file=$current_archive/tddft.err
      ;;
    *)
      error_file=
      ;;
  esac
  if [ -n "$error_file" ] && [ -f "$error_file" ]; then
    echo "FPSEID_STEP115_ERROR_TAIL_BEGIN"
    tail -n 8 "$error_file"
    echo "FPSEID_STEP115_ERROR_TAIL_END"
  fi
  echo "Stop here; do not continue the H100 baseline series."
  exit 1
}

validate_existing_archive() {
  run_no=$1
  label=nvhpc_cufft_1rank_02_STEP115_H100_CC90_BASELINE_$run_no
  archive_dir=$ROOT_DIR/run/tddft_archives/$label
  metadata=$archive_dir/step115.env

  if [ ! -f "$archive_dir/tddft.out" ] ||
     [ ! -f "$archive_dir/tddft.err" ] ||
     [ ! -f "$metadata" ]; then
    echo "ERROR: incomplete Step 115 archive: $label" >&2
    exit 1
  fi
  archived_revision=$(sed -n 's/^revision=//p' "$metadata")
  archived_flags=$(sed -n 's/^flags=//p' "$metadata")
  archived_device=$(sed -n 's/^device=//p' "$metadata")
  if [ "$archived_revision" != "$CURRENT_REVISION" ] ||
     [ "$archived_flags" != "$EFFECTIVE_FLAGS" ] ||
     [ "$archived_device" != "$device" ]; then
    echo "ERROR: existing Step 115 archive provenance mismatch: $label" >&2
    exit 1
  fi
}

need_build=0
for run_no in 01 02 03
do
  label=nvhpc_cufft_1rank_02_STEP115_H100_CC90_BASELINE_$run_no
  archive_dir=$ROOT_DIR/run/tddft_archives/$label
  if [ -e "$archive_dir" ]; then
    validate_existing_archive "$run_no"
  else
    need_build=1
  fi
done

if [ "$need_build" = 1 ]; then
  echo
  echo "STEP115 building current accepted TDDFT path for H100 cc90"
  if ! FPSEID_FRPRMN_DIAGNOSTIC=0 \
      TDDFT_FFLAGS="$BASE_FLAGS" \
      TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
      "$SCRIPT_DIR/build_nvhpc.sh"; then
    print_failure build
  fi
fi

for run_no in 01 02 03
do
  current_run=$run_no
  current_label=nvhpc_cufft_1rank_02_STEP115_H100_CC90_BASELINE_$run_no
  current_archive=$ROOT_DIR/run/tddft_archives/$current_label

  if [ -e "$current_archive" ]; then
    validate_existing_archive "$run_no"
    echo
    echo "STEP115 reusing validated archive run=$run_no"
  else
    echo
    echo "STEP115 running H100 baseline candidate run=$run_no"
    cd "$RUN_DIR"
    ulimit -s unlimited 2>/dev/null || true
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=512M
    export CUDA_VISIBLE_DEVICES=$GPU_ID
    if ! mpirun -np 1 \
        "$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" \
        < Si111-H_tm.in_100steps \
        > Si111-H_tm.out_100steps \
        2> Si111-H_tm.err; then
      cd "$ROOT_DIR"
      print_failure run
    fi

    cd "$ROOT_DIR"
    if ! LABEL="$current_label" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
        TDDFT_ERR=Si111-H_tm.err \
        "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null; then
      print_failure archive
    fi
    {
      echo "revision=$CURRENT_REVISION"
      echo "flags=$EFFECTIVE_FLAGS"
      echo "device=$device"
      echo "compiler=$compiler"
    } > "$current_archive/step115.env"
  fi

  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$current_archive/tddft.out" --err "$current_archive/tddft.err" \
      --expected-steps 100 >/dev/null; then
    python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$current_archive/tddft.out" --err "$current_archive/tddft.err" \
      --expected-steps 100 || true
    print_failure check
  fi
  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$current_archive/tddft.out" \
      --test-err "$current_archive/tddft.err" \
      --expected-steps 100 >/dev/null; then
    python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$current_archive/tddft.out" \
      --test-err "$current_archive/tddft.err" \
      --expected-steps 100 || true
    print_failure relaxed_compare
  fi

  pairwise_strict=PASS
  if [ "$run_no" != 01 ]; then
    reference=$ROOT_DIR/run/tddft_archives/\
nvhpc_cufft_1rank_02_STEP115_H100_CC90_BASELINE_01
    if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
        "$reference/tddft.out" "$current_archive/tddft.out" \
        --ref-err "$reference/tddft.err" \
        --test-err "$current_archive/tddft.err" \
        --expected-steps 100 --strict >/dev/null; then
      pairwise_strict=FAIL
    fi
  fi

  wall=$(awk '
    /steps took/ {
      value=$(NF-1)
      gsub(/[dD]/,"E",value)
    }
    END { printf "%.10f", value+0.0 }
  ' "$current_archive/tddft.out")
  wall_values="${wall_values}
$wall"
  summary_lines="${summary_lines}
$run_no $wall PASS PASS $pairwise_strict"
done

sorted_walls=$(printf '%s\n' "$wall_values" |
  sed '/^[[:space:]]*$/d' | sort -n)
minimum=$(printf '%s\n' "$sorted_walls" | sed -n '1p')
median=$(printf '%s\n' "$sorted_walls" | sed -n '2p')
maximum=$(printf '%s\n' "$sorted_walls" | sed -n '3p')
run_range=$(awk -v low="$minimum" -v high="$maximum" \
  'BEGIN { printf "%.10f", high-low }')
a100_ratio=$(awk -v a100="$A100_MEDIAN" -v h100="$median" \
  'BEGIN { printf "%.6f", a100/h100 }')
wall_reduction=$(awk -v a100="$A100_MEDIAN" -v h100="$median" \
  'BEGIN { printf "%.6f", 100.0*(a100-h100)/a100 }')

echo
echo "FPSEID21 STEP115 H100 CC90 BASELINE CANDIDATE SUMMARY"
echo "revision=$CURRENT_REVISION"
echo "accepted_numerical_source=c46cfa9"
echo "diagnostic=OFF gpu=H100 mpi_ranks=1 steps=100"
echo "compiler=$compiler"
echo "device=$device"
echo "kernel=$(uname -r)"
echo "flags=$EFFECTIVE_FLAGS"
echo "FPSEID_H100_BASELINE_BEGIN"
echo "run wall_sec check relaxed run01_pairwise_strict"
printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
echo "median_sec=$median"
echo "range_sec=$run_range"
echo "a100_step107_median_sec=$A100_MEDIAN"
echo "a100_over_h100_ratio=$a100_ratio"
echo "h100_wall_reduction_vs_a100_pct=$wall_reduction"
echo "FPSEID_H100_BASELINE_END"
echo "H100-only baseline candidate; do not replace or mix with the A100 baseline."
