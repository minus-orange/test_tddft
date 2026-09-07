#!/bin/sh
set -eu

# Build TDDFT, optionally together with CG and SD, using NVIDIA HPC SDK.
# Load the NVIDIA HPC SDK environment before running this script so that
# nvfortran and the intended MPI wrapper are on PATH.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

VERSION=${VERSION:-3.3.11}
FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-${VERSION}-nvhpc/install"}
SKIP_FFTW=${SKIP_FFTW:-0}
ENABLE_GPU_FFT=${ENABLE_GPU_FFT:-0}
BUILD_REPORT=${BUILD_REPORT:-0}
ENABLE_PINNED_ALLOC=${ENABLE_PINNED_ALLOC:-0}
TDDFT_ONLY=${TDDFT_ONLY:-0}
FPSEID_COST_DETAIL_TIMERS=${FPSEID_COST_DETAIL_TIMERS:-0}

NVFORTRAN=${NVFORTRAN:-nvfortran}
MPI_FC=${MPI_FC:-mpifort}
MPI_CC=${MPI_CC:-mpicc}
GPU_CC=${GPU_CC:-nvc}
FFTW_CC=${FFTW_CC:-cc}
FFTW_FC=${FFTW_FC:-gfortran}
FFTW_F77=${FFTW_F77:-$FFTW_FC}

CG_FFLAGS=${CG_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
SD_FFLAGS=${SD_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
TDDFT_FFLAGS=${TDDFT_FFLAGS:-"-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays"}
TDDFT_FFTW_LIBS=${TDDFT_FFTW_LIBS:-"-lfftw3_omp -lfftw3 -lgomp"}
TDDFT_CUFFT_LIBS=${TDDFT_CUFFT_LIBS:-"-cudalib=cufft"}
GPU_CFLAGS=${GPU_CFLAGS:-}
NVHPC_REPORT_FLAGS=${NVHPC_REPORT_FLAGS:-"-Minfo=accel -Minfo=mp"}

case "$ENABLE_PINNED_ALLOC" in
  0) ;;
  1)
    if [ "$ENABLE_GPU_FFT" != 1 ]; then
      echo "ERROR: ENABLE_PINNED_ALLOC=1 requires ENABLE_GPU_FFT=1." >&2
      exit 1
    fi
    TDDFT_FFLAGS="$TDDFT_FFLAGS -gpu=mem:separate:pinnedalloc"
    ;;
  *)
    echo "ERROR: ENABLE_PINNED_ALLOC must be 0 or 1." >&2
    exit 1
    ;;
esac

case "$TDDFT_ONLY" in
  0|1) ;;
  *)
    echo "ERROR: TDDFT_ONLY must be 0 or 1." >&2
    exit 1
    ;;
esac

case "$FPSEID_COST_DETAIL_TIMERS" in
  0|1) ;;
  *)
    echo "ERROR: FPSEID_COST_DETAIL_TIMERS must be 0 or 1." >&2
    exit 1
    ;;
esac

find_gcc_runtime_dir() {
  compiler=$1
  runtime_lib=$2

  if ! command -v "$compiler" >/dev/null 2>&1; then
    return 1
  fi

  path=$("$compiler" -print-file-name="$runtime_lib" 2>/dev/null || true)
  case "$path" in
    */"$runtime_lib")
      dirname -- "$path"
      ;;
    *)
      return 1
      ;;
  esac
}

find_cuda_root() {
  for var in CUDA_HOME NVHPC_CUDA_HOME CUDA_PATH; do
    eval value=\${$var:-}
    if [ -n "$value" ] &&
       [ -f "$value/include/cuda_runtime.h" ] &&
       [ -f "$value/include/cufft.h" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  done

  if command -v "$GPU_CC" >/dev/null 2>&1; then
    cc_path=$(command -v "$GPU_CC")
    nvhpc_root=$(CDPATH= cd -- "$(dirname -- "$cc_path")/../.." 2>/dev/null && pwd || true)
    if [ -n "$nvhpc_root" ]; then
      for dir in "$nvhpc_root"/cuda "$nvhpc_root"/cuda/*; do
        if [ -f "$dir/include/cuda_runtime.h" ] &&
           [ -f "$dir/include/cufft.h" ]; then
          printf '%s\n' "$dir"
          return 0
        fi
      done
    fi
  fi

  return 1
}

find_cuda_include_dir() {
  header=$1

  if [ -n "${CUDA_ROOT:-}" ] && [ -f "$CUDA_ROOT/include/$header" ]; then
    dirname -- "$CUDA_ROOT/include/$header"
    return 0
  fi

  for var in CUDA_HOME NVHPC_CUDA_HOME CUDA_PATH; do
    eval value=\${$var:-}
    if [ -n "$value" ] && [ -f "$value/include/$header" ]; then
      dirname -- "$value/include/$header"
      return 0
    fi
  done

  if command -v "$GPU_CC" >/dev/null 2>&1; then
    cc_path=$(command -v "$GPU_CC")
    nvhpc_root=$(CDPATH= cd -- "$(dirname -- "$cc_path")/../.." 2>/dev/null && pwd || true)
    if [ -n "$nvhpc_root" ]; then
      for dir in "$nvhpc_root"/cuda "$nvhpc_root"/cuda/* \
                 "$nvhpc_root"/math_libs "$nvhpc_root"/math_libs/*; do
        if [ -f "$dir/include/$header" ]; then
          dirname -- "$dir/include/$header"
          return 0
        fi
      done
    fi
  fi

  for dir in /usr/local/cuda /usr/local/cuda-* /opt/cuda /opt/cuda-*; do
    if [ -f "$dir/include/$header" ]; then
      dirname -- "$dir/include/$header"
      return 0
    fi
  done

  return 1
}

if ! command -v "$NVFORTRAN" >/dev/null 2>&1; then
  echo "ERROR: $NVFORTRAN was not found. Load NVIDIA HPC SDK first." >&2
  exit 1
fi
if ! command -v "$MPI_FC" >/dev/null 2>&1; then
  echo "ERROR: $MPI_FC was not found. Load the MPI environment first." >&2
  exit 1
fi
if [ "$ENABLE_GPU_FFT" = 1 ] && ! command -v "$GPU_CC" >/dev/null 2>&1; then
  echo "ERROR: $GPU_CC was not found. Set GPU_CC to a C compiler that can find CUDA headers." >&2
  exit 1
fi
if [ "$ENABLE_GPU_FFT" = 1 ]; then
  CUDA_ROOT=${CUDA_ROOT:-$(find_cuda_root || true)}
  CUDA_RUNTIME_INCLUDE=${CUDA_RUNTIME_INCLUDE:-$(find_cuda_include_dir cuda_runtime.h || true)}
  CUFFT_INCLUDE=${CUFFT_INCLUDE:-$(find_cuda_include_dir cufft.h || true)}
  if [ -z "$CUDA_RUNTIME_INCLUDE" ] && [ -z "$GPU_CFLAGS" ]; then
    echo "ERROR: cuda_runtime.h was not found." >&2
    echo "Set CUDA_ROOT, CUDA_HOME, NVHPC_CUDA_HOME, CUDA_RUNTIME_INCLUDE, or GPU_CFLAGS." >&2
    exit 1
  fi
  if [ -z "$CUFFT_INCLUDE" ] && [ -z "$GPU_CFLAGS" ]; then
    echo "ERROR: cufft.h was not found." >&2
    echo "Set CUDA_ROOT, CUDA_HOME, NVHPC_CUDA_HOME, CUFFT_INCLUDE, or GPU_CFLAGS." >&2
    exit 1
  fi
  if [ -n "$CUDA_RUNTIME_INCLUDE" ]; then
    GPU_CFLAGS="$GPU_CFLAGS -I$CUDA_RUNTIME_INCLUDE"
  fi
  if [ -n "$CUFFT_INCLUDE" ] && [ "$CUFFT_INCLUDE" != "$CUDA_RUNTIME_INCLUDE" ]; then
    GPU_CFLAGS="$GPU_CFLAGS -I$CUFFT_INCLUDE"
  fi
  if [ -n "$CUDA_ROOT" ] && [ -d "$CUDA_ROOT/lib64" ]; then
    TDDFT_CUFFT_LIBS="$TDDFT_CUFFT_LIBS -L$CUDA_ROOT/lib64"
  fi
fi
if [ "$ENABLE_GPU_FFT" != 1 ]; then
  if ! command -v "$FFTW_CC" >/dev/null 2>&1; then
    echo "ERROR: $FFTW_CC was not found. Set FFTW_CC to a working C compiler." >&2
    exit 1
  fi
  if [ "$FFTW_FC" != none ] && ! command -v "$FFTW_FC" >/dev/null 2>&1; then
    echo "ERROR: $FFTW_FC was not found. Set FFTW_FC/F77 to gfortran or use an existing FFTW_ROOT." >&2
    exit 1
  fi
fi

if [ "$ENABLE_GPU_FFT" != 1 ] &&
   [ "$SKIP_FFTW" != 1 ] &&
   [ ! -f "$FFTW_ROOT/include/fftw3.f" ]; then
  echo "Building FFTW3 under $FFTW_ROOT with CC=$FFTW_CC FC=$FFTW_FC F77=$FFTW_F77"
  PREFIX="$FFTW_ROOT" CC="$FFTW_CC" FC="$FFTW_FC" F77="$FFTW_F77" "$SCRIPT_DIR/build_fftw3.sh"
fi

if [ "$TDDFT_ONLY" = 1 ]; then
  echo "Skipping CG and SD builds (TDDFT_ONLY=1)."
else
  echo "Building CG with $NVFORTRAN"
  (
    cd "$ROOT_DIR/FPSEID21/cg_GGA_f_code"
    FC="$NVFORTRAN" FFLAGS="$CG_FFLAGS" ./mk_ifort.sh
  )

  echo "Building SD with $NVFORTRAN"
  (
    cd "$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code"
    FC="$NVFORTRAN" FFLAGS="$SD_FFLAGS" ./mk_ifort.sh
  )
fi

echo "Building TDDFT with $MPI_FC"
echo "TDDFT pinned host allocation: $ENABLE_PINNED_ALLOC"
echo "TDDFT requested flags: $TDDFT_FFLAGS"
(
  cd "$ROOT_DIR/FPSEID21/tddft_2022October"
  if [ "$ENABLE_GPU_FFT" = 1 ]; then
    echo "Using CUDA_ROOT=$CUDA_ROOT"
    echo "Using CUDA_RUNTIME_INCLUDE=$CUDA_RUNTIME_INCLUDE"
    echo "Using CUFFT_INCLUDE=$CUFFT_INCLUDE"
    echo "Using GPU_CFLAGS=$GPU_CFLAGS"
    echo "Using BUILD_REPORT=$BUILD_REPORT"
    FC="$MPI_FC" CC="$GPU_CC" CFLAGS="$GPU_CFLAGS" FFLAGS="$TDDFT_FFLAGS" \
      FPSEID_COST_DETAIL_TIMERS="$FPSEID_COST_DETAIL_TIMERS" \
      BUILD_REPORT="$BUILD_REPORT" REPORT_FLAGS="$NVHPC_REPORT_FLAGS" \
      FFT_BACKEND=cufft CUFFT_LIBS="$TDDFT_CUFFT_LIBS" ./mk_ifort.sh
  else
    FC="$MPI_FC" CC="$MPI_CC" FFLAGS="$TDDFT_FFLAGS" FFTW_ROOT="$FFTW_ROOT" \
      FPSEID_COST_DETAIL_TIMERS="$FPSEID_COST_DETAIL_TIMERS" \
      BUILD_REPORT="$BUILD_REPORT" REPORT_FLAGS="$NVHPC_REPORT_FLAGS" \
      FFTW_LIBS="$TDDFT_FFTW_LIBS" ./mk_ifort.sh
  fi
)

echo "NVIDIA HPC SDK build complete."
if [ "$ENABLE_GPU_FFT" = 1 ]; then
  echo "FFT_BACKEND=cufft"
else
  echo "FFTW_ROOT=$FFTW_ROOT"
fi

GCC_RUNTIME_DIR=${GCC_RUNTIME_DIR:-}
if [ -z "$GCC_RUNTIME_DIR" ]; then
  GCC_RUNTIME_DIR=$(find_gcc_runtime_dir "$FFTW_FC" libatomic.so.1 || true)
fi
if [ -n "$GCC_RUNTIME_DIR" ]; then
  echo
  echo "Runtime environment for GNU OpenMP/libatomic dependencies:"
  echo "  export LD_LIBRARY_PATH=$GCC_RUNTIME_DIR:\${LD_LIBRARY_PATH:-}"
fi
