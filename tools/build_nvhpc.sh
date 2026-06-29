#!/bin/sh
set -eu

# Build CG, SD, and TDDFT with NVIDIA HPC SDK compilers.
# Load the NVIDIA HPC SDK environment before running this script so that
# nvfortran, nvc, and the intended MPI wrapper are on PATH.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

VERSION=${VERSION:-3.3.11}
FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-${VERSION}-nvhpc/install"}
SKIP_FFTW=${SKIP_FFTW:-0}

NVFORTRAN=${NVFORTRAN:-nvfortran}
NVC=${NVC:-nvc}
MPI_FC=${MPI_FC:-mpifort}
MPI_CC=${MPI_CC:-mpicc}

CG_FFLAGS=${CG_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
SD_FFLAGS=${SD_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
TDDFT_FFLAGS=${TDDFT_FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}

if ! command -v "$NVFORTRAN" >/dev/null 2>&1; then
  echo "ERROR: $NVFORTRAN was not found. Load NVIDIA HPC SDK first." >&2
  exit 1
fi
if ! command -v "$NVC" >/dev/null 2>&1; then
  echo "ERROR: $NVC was not found. Load NVIDIA HPC SDK first." >&2
  exit 1
fi
if ! command -v "$MPI_FC" >/dev/null 2>&1; then
  echo "ERROR: $MPI_FC was not found. Load the MPI environment first." >&2
  exit 1
fi

if [ "$SKIP_FFTW" != 1 ] && [ ! -f "$FFTW_ROOT/include/fftw3.f" ]; then
  echo "Building FFTW3 for NVIDIA HPC SDK under $FFTW_ROOT"
  PREFIX="$FFTW_ROOT" CC="$NVC" FC="$NVFORTRAN" "$SCRIPT_DIR/build_fftw3.sh"
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
  FC="$MPI_FC" CC="$MPI_CC" FFLAGS="$TDDFT_FFLAGS" FFTW_ROOT="$FFTW_ROOT" ./mk_ifort.sh
)

echo "NVIDIA HPC SDK build complete."
echo "FFTW_ROOT=$FFTW_ROOT"
