#!/bin/sh
set -eu

# Build CG, SD, and TDDFT with NVIDIA HPC SDK compilers.
# Load the NVIDIA HPC SDK environment before running this script so that
# nvfortran and the intended MPI wrapper are on PATH.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

VERSION=${VERSION:-3.3.11}
FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-${VERSION}-nvhpc/install"}
SKIP_FFTW=${SKIP_FFTW:-0}
ENABLE_GPU_FFT=${ENABLE_GPU_FFT:-0}

NVFORTRAN=${NVFORTRAN:-nvfortran}
MPI_FC=${MPI_FC:-mpifort}
MPI_CC=${MPI_CC:-mpicc}
GPU_CC=${GPU_CC:-nvc}
FFTW_CC=${FFTW_CC:-cc}
FFTW_FC=${FFTW_FC:-gfortran}
FFTW_F77=${FFTW_F77:-$FFTW_FC}

CG_FFLAGS=${CG_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
SD_FFLAGS=${SD_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
TDDFT_FFLAGS=${TDDFT_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
TDDFT_FFTW_LIBS=${TDDFT_FFTW_LIBS:-"-lfftw3_omp -lfftw3 -lgomp"}
TDDFT_CUFFT_LIBS=${TDDFT_CUFFT_LIBS:-"-cudalib=cufft"}

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

echo "Building TDDFT with $MPI_FC"
(
  cd "$ROOT_DIR/FPSEID21/tddft_2022October"
  if [ "$ENABLE_GPU_FFT" = 1 ]; then
    FC="$MPI_FC" CC="$GPU_CC" FFLAGS="$TDDFT_FFLAGS" \
      FFT_BACKEND=cufft CUFFT_LIBS="$TDDFT_CUFFT_LIBS" ./mk_ifort.sh
  else
    FC="$MPI_FC" CC="$MPI_CC" FFLAGS="$TDDFT_FFLAGS" FFTW_ROOT="$FFTW_ROOT" \
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
