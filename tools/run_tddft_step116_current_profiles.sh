#!/bin/sh
set -eu

# Profile the current accepted numerical path with Nsight Systems and one
# Nsight Compute launch. Both runs are diagnostic-only and use the 100-step
# Si111-H input so normal check and relaxed compare can both be required.
# The default rebuilds TDDFT exactly once, then reuses that executable for the
# two profiler runs.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
TARGET_GPU=${TARGET_GPU:-}
PROFILE_RUN=${PROFILE_RUN:-01}
NCU_USE_SUDO=${NCU_USE_SUDO:-0}
BUILD_MODE=${BUILD_MODE:-always}
DRY_RUN=${DRY_RUN:-0}
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}

case "$TARGET_GPU" in
  A100)
    GPU_ARCH=cc80
    NSYS_LABEL=${NSYS_LABEL:-nvhpc_cufft_1rank_02_STEP116_A100_CURRENT_NSYS_$PROFILE_RUN}
    NCU_LABEL=${NCU_LABEL:-nvhpc_cufft_1rank_02_STEP116_A100_FUSED_NCU_$PROFILE_RUN}
    ;;
  H100)
    GPU_ARCH=cc90
    NSYS_LABEL=${NSYS_LABEL:-nvhpc_cufft_1rank_02_STEP116_H100_CURRENT_NSYS_$PROFILE_RUN}
    NCU_LABEL=${NCU_LABEL:-nvhpc_cufft_1rank_02_STEP116_H100_FUSED_NCU_$PROFILE_RUN}
    ;;
  *)
    echo "ERROR: set TARGET_GPU=A100 or TARGET_GPU=H100." >&2
    exit 2
    ;;
esac
BASE_FLAGS="-O2 -acc -gpu=$GPU_ARCH -mp -Msave -Mlarge_arrays"
profile_tag=$(printf '%s' "$TARGET_GPU" | tr '[:upper:]' '[:lower:]')

case "$PROFILE_RUN" in
  [0-9][0-9]) ;;
  *)
    echo "ERROR: PROFILE_RUN must be a two-digit run number such as 01." >&2
    exit 2
    ;;
esac
case "$NCU_USE_SUDO" in
  0|1) ;;
  *)
    echo "ERROR: NCU_USE_SUDO must be 0 or 1." >&2
    exit 2
    ;;
esac

case "$BUILD_MODE" in
  always|never) ;;
  *)
    echo "ERROR: BUILD_MODE must be always or never." >&2
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
  echo "ERROR: prepared 100-step input is missing: $RUN_DIR" >&2
  exit 1
fi
if [ -e "$ROOT_DIR/run/nsys_archives/$NSYS_LABEL" ]; then
  echo "ERROR: Nsight Systems archive already exists: $NSYS_LABEL" >&2
  exit 1
fi
if [ -e "$ROOT_DIR/run/ncu_archives/$NCU_LABEL" ]; then
  echo "ERROR: Nsight Compute archive already exists: $NCU_LABEL" >&2
  exit 1
fi

echo "FPSEID21 STEP116 CURRENT-SOURCE PROFILER PREFLIGHT"
echo "revision=$(git rev-parse HEAD)"
echo "numerical_source=c46cfa9"
echo "target_gpu=$TARGET_GPU gpu_arch=$GPU_ARCH gpu_id=$GPU_ID"
echo "profile_run=$PROFILE_RUN ncu_use_sudo=$NCU_USE_SUDO"
echo "run_dir=$RUN_DIR"
echo "build_mode=$BUILD_MODE"
echo "nsys_label=$NSYS_LABEL"
echo "ncu_label=$NCU_LABEL"
echo "flags=$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
echo "configuration=1_GPU_1_MPI_rank_OMP_1_diagnostic_OFF"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi was not found." >&2
  exit 1
else
  device=$(nvidia-smi -i "$GPU_ID" \
    --query-gpu=name,compute_cap,memory.total,memory.used,utilization.gpu \
    --format=csv,noheader 2>/dev/null | sed -n '1p' || true)
  echo "device=$device"
  case "$TARGET_GPU:$device" in
    A100:*A100*) ;;
    H100:*H100*) ;;
    *)
      echo "ERROR: detected device does not match TARGET_GPU=$TARGET_GPU." >&2
      exit 1
      ;;
  esac
  gpu_processes=$(nvidia-smi -i "$GPU_ID" \
    --query-compute-apps=pid,process_name,used_memory \
    --format=csv,noheader 2>/dev/null || true)
  if [ -n "$gpu_processes" ]; then
    echo "ERROR: GPU has an active compute process; stop before profiling." >&2
    echo "$gpu_processes" >&2
    exit 1
  fi
fi

if [ "$DRY_RUN" = 1 ]; then
  echo "dry_run=1"
  echo "Would build TDDFT once when BUILD_MODE=always, then run NSYS and NCU."
  exit 0
fi

if [ "$BUILD_MODE" = always ]; then
  FPSEID_FRPRMN_DIAGNOSTIC=0 \
  TDDFT_FFLAGS="$BASE_FLAGS" \
  TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
    "$ROOT_DIR/tools/build_nvhpc.sh"
elif [ ! -x "$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" ]; then
  echo "ERROR: BUILD_MODE=never but TDDFT executable is missing." >&2
  exit 1
fi

export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=$GPU_ID

NSYS_LOG=$ROOT_DIR/run/step116_${profile_tag}_current_nsys_driver.log
if ! LABEL="$NSYS_LABEL" TDDFT_INPUT=Si111-H_tm.in_100steps \
    NSYS_TRACE=cuda,openacc,nvtx,osrt,mpi \
    "$ROOT_DIR/tools/profile_tddft_nsys.sh" "$RUN_DIR" \
    > "$NSYS_LOG" 2>&1; then
  tail -n 100 "$NSYS_LOG"
  exit 1
fi

NSYS_DIR=$ROOT_DIR/run/nsys_archives/$NSYS_LABEL
python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
  "$NSYS_DIR/tddft.out" --expected-steps 100 >/dev/null
python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
  "$NSYS_DIR/tddft.out" --expected-steps 100 >/dev/null

NCU_LOG=$ROOT_DIR/run/step116_${profile_tag}_current_ncu_driver.log
if [ "$NCU_USE_SUDO" = 1 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: NCU_USE_SUDO=1 but sudo was not found." >&2
    exit 1
  fi
  if ! sudo -E /usr/bin/env \
      PATH="$PATH" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" \
      LABEL="$NCU_LABEL" TDDFT_INPUT=Si111-H_tm.in_100steps \
      NCU_KERNEL_NAME=regex:exnlp_gemm_body_fused \
      NCU_LAUNCH_COUNT=1 NCU_SET=full \
      OMP_NUM_THREADS=1 OMP_STACKSIZE=512M \
      CUDA_VISIBLE_DEVICES="$GPU_ID" \
      "$ROOT_DIR/tools/profile_tddft_ncu.sh" "$RUN_DIR" \
      > "$NCU_LOG" 2>&1; then
    tail -n 100 "$NCU_LOG"
    exit 1
  fi
else
  if ! LABEL="$NCU_LABEL" TDDFT_INPUT=Si111-H_tm.in_100steps \
      NCU_KERNEL_NAME=regex:exnlp_gemm_body_fused \
      NCU_LAUNCH_COUNT=1 NCU_SET=full \
      "$ROOT_DIR/tools/profile_tddft_ncu.sh" "$RUN_DIR" \
      > "$NCU_LOG" 2>&1; then
    tail -n 100 "$NCU_LOG"
    exit 1
  fi
fi

NCU_DIR=$ROOT_DIR/run/ncu_archives/$NCU_LABEL
python3 "$ROOT_DIR/tools/check_tddft_result.py" check \
  "$NCU_DIR/tddft.out" --err "$NCU_DIR/tddft.err" \
  --expected-steps 100 >/dev/null
python3 "$ROOT_DIR/tools/check_tddft_result.py" compare \
  "$NCU_DIR/tddft.out" --test-err "$NCU_DIR/tddft.err" \
  --expected-steps 100 >/dev/null

echo
echo "FPSEID21 STEP116 $TARGET_GPU CURRENT NSYS + NCU SUMMARY"
echo "revision=$(git rev-parse HEAD)"
echo "numerical_source=c46cfa9"
echo "target_gpu=$TARGET_GPU gpu_arch=$GPU_ARCH"
echo "profile_run=$PROFILE_RUN ncu_use_sudo=$NCU_USE_SUDO"
echo "diagnostic=OFF profiler_runs=ON check=PASS compare=PASS"
echo "nsys_label=$NSYS_LABEL"
echo "ncu_label=$NCU_LABEL"
grep 'steps took' "$NSYS_DIR/tddft.out" | tail -n 1

for report in cuda_gpu_kern_sum cuda_gpu_mem_time_sum \
  cuda_gpu_mem_size_sum cuda_api_sum openacc_sum mpi_sum
do
  csv=$NSYS_DIR/$report.csv
  if [ -f "$csv" ]; then
    echo
    echo "[$report: first 8 rows]"
    sed -n '1,9p' "$csv"
  fi
done

echo
echo "[Nsight Compute: selected fused-kernel launch]"
cat "$NCU_DIR/ncu-summary.txt"
echo
echo "Both profiler walls include profiler overhead and are not baselines."
echo "Return photographs from STEP116 $TARGET_GPU CURRENT NSYS + NCU SUMMARY through this line."
