#!/bin/sh
set -eu

# Measure the Step 119 timer tree on exactly one A100 or H100.
# This is a one-run instrumentation validation, not a baseline replacement.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
PLATFORM=${1:-}
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}

case "$PLATFORM" in
  A100)
    GPU_ARCH=cc80
    DEVICE_PATTERN=A100
    ;;
  H100)
    GPU_ARCH=cc90
    DEVICE_PATTERN=H100
    ;;
  *)
    echo "Usage: $0 A100|H100" >&2
    exit 2
    ;;
esac

case "$GPU_ID" in
  *,*)
    echo "ERROR: expose exactly one GPU through CUDA_VISIBLE_DEVICES." >&2
    exit 2
    ;;
esac

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

device=$(nvidia-smi -i "$GPU_ID" --query-gpu=name,driver_version \
  --format=csv,noheader 2>/dev/null | sed -n '1p' || true)
case "$device" in
  *"$DEVICE_PATTERN"*) ;;
  *)
    echo "ERROR: requested $PLATFORM but detected: $device" >&2
    exit 1
    ;;
esac

revision=$(git rev-parse HEAD)
short_revision=$(git rev-parse --short=12 HEAD)
timestamp=$(date '+%Y%m%d_%H%M%S')
label=nvhpc_cufft_1rank_02_STEP119_${PLATFORM}_TIMER_TREE_\
${timestamp}_${short_revision}_01
archive_dir=$ROOT_DIR/run/tddft_archives/$label
if [ -e "$archive_dir" ]; then
  echo "ERROR: archive label already exists: $label" >&2
  exit 1
fi

base_flags="-O2 -acc -gpu=$GPU_ARCH -mp -Msave -Mlarge_arrays"
effective_flags="$base_flags -gpu=mem:separate:pinnedalloc"

print_failure() {
  failure_stage=$1
  echo
  echo "FPSEID_STEP119_GPU_FAILURE_BEGIN"
  echo "revision=$revision"
  echo "platform=$PLATFORM"
  echo "device=$device"
  echo "stage=$failure_stage"
  echo "label=$label"
  case "$failure_stage" in
    run|archive)
      error_file=$RUN_DIR/Si111-H_tm.err
      ;;
    normal_check|relaxed_compare|timer_tree_missing)
      error_file=$archive_dir/tddft.err
      ;;
    *)
      error_file=
      ;;
  esac
  if [ -n "$error_file" ] && [ -f "$error_file" ]; then
    echo "stderr_tail_begin"
    tail -n 12 "$error_file"
    echo "stderr_tail_end"
  fi
  echo "Stop here; do not run another Step 119 GPU measurement."
  echo "FPSEID_STEP119_GPU_FAILURE_END"
  exit 1
}

echo "STEP119 building timer-tree validation for $PLATFORM ($GPU_ARCH)"
if ! FPSEID_FRPRMN_DIAGNOSTIC=0 TDDFT_FFLAGS="$base_flags" \
    TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
    "$ROOT_DIR/tools/build_nvhpc.sh"; then
  print_failure build
fi

cd "$RUN_DIR"
ulimit -s unlimited 2>/dev/null || true
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=$GPU_ID
if ! mpirun -np 1 "$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" \
    < Si111-H_tm.in_100steps \
    > Si111-H_tm.out_100steps \
    2> Si111-H_tm.err; then
  cd "$ROOT_DIR"
  print_failure run
fi

cd "$ROOT_DIR"
if ! LABEL="$label" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
    TDDFT_ERR=Si111-H_tm.err \
    "$ROOT_DIR/tools/archive_tddft_result.sh" "$RUN_DIR" >/dev/null; then
  print_failure archive
fi

if ! python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
    "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null; then
  python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
    "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
    --expected-steps 100 || true
  print_failure normal_check
fi
if ! python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
    "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null; then
  python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
    "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
    --expected-steps 100 || true
  print_failure relaxed_compare
fi
if ! grep -q '^\[Timer Output\]' "$archive_dir/tddft.out"; then
  print_failure timer_tree_missing
fi

wall=$(awk '/steps took/ { value=$(NF-1) } END {
  if (value == "") exit 1
  gsub(/[dD]/, "E", value)
  printf "%.10f", value + 0
}' "$archive_dir/tddft.out")

{
  echo "revision=$revision"
  echo "platform=$PLATFORM"
  echo "device=$device"
  echo "gpu_arch=$GPU_ARCH"
  echo "flags=$effective_flags"
  echo "diagnostic=OFF"
  echo "normal_check=PASS"
  echo "relaxed_compare=PASS"
  echo "wall_sec=$wall"
} > "$archive_dir/step119_gpu_timer_tree.env"

echo
echo "FPSEID_STEP119_GPU_TIMER_TREE_BEGIN"
sed -n '/^\[Timer Output\]/,/^[[:space:]]*FPSEID_PROFILE_BEGIN/p' \
  "$archive_dir/tddft.out" | sed '$d'
echo "FPSEID_STEP119_GPU_TIMER_TREE_END"

echo
echo "FPSEID_STEP119_GPU_SUMMARY_BEGIN"
echo "revision=$revision"
echo "platform=$PLATFORM"
echo "device=$device"
echo "gpu_arch=$GPU_ARCH"
echo "flags=$effective_flags"
echo "runs=1 mpi_ranks=1 omp_num_threads=1 diagnostic=OFF"
echo "label=$label"
echo "wall_sec=$wall check=PASS compare=PASS"
echo "archive=$archive_dir"
echo "measurement_type=instrumentation_validation_not_baseline"
echo "FPSEID_STEP119_GPU_SUMMARY_END"
