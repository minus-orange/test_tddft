#!/bin/sh
set -eu

# Intel/MPI + FFTW3 build for the profiled FPSEID21 TDDFT executable.
#
# Required environment:
#   FC         MPI Fortran compiler wrapper. Default: mpiifort
#   FFTW_ROOT  FFTW3 installation prefix containing include/ and lib/.
#
# Optional:
#   CC         C compiler wrapper for the FFTW thread API shim. Default: mpicc
#   FFLAGS     Fortran flags. Default depends on FC.
#   CFLAGS     Additional C flags.
#   LDFLAGS    Additional linker flags.
#   FFTW_LIBS  FFTW libraries. Default: -lfftw3_omp -lfftw3

FC=${FC:-mpiifort}
CC=${CC:-mpicc}
FFTW_ROOT=${FFTW_ROOT:-}
case "$FC" in
  *gfortran*|*mpifort*)
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    ;;
  *)
    FFLAGS=${FFLAGS:-"-O3 -traceback -qopenmp"}
    ;;
esac
CFLAGS=${CFLAGS:-"-O2"}
LDFLAGS=${LDFLAGS:-}
FFTW_LIBS=${FFTW_LIBS:-"-lfftw3_omp -lfftw3"}

if [ -z "$FFTW_ROOT" ]; then
  echo "ERROR: FFTW_ROOT is not set." >&2
  echo "Example:" >&2
  echo "  FFTW_ROOT=\$PWD/../../tools/fftw-3.3.11/install ./mk_ifort.sh" >&2
  exit 1
fi

if [ ! -f "$FFTW_ROOT/include/fftw3.f" ]; then
  echo "ERROR: fftw3.f was not found under $FFTW_ROOT/include." >&2
  echo "Run ../../tools/build_fftw3.sh first, or set FFTW_ROOT correctly." >&2
  exit 1
fi

set -x
"$CC" $CFLAGS -I"$FFTW_ROOT/include" -c fftw_threads_fwrap.c \
  -o fftw_threads_fwrap.o
"$FC" $FFLAGS \
  -I"$FFTW_ROOT/include" \
  -o tddft_exe \
  cpu_block.f prof_timer.f lib4_ASL_2_check_Vext_SXACE.f \
  rarr3.f tm_inputs.f \
  rexgenDummy.f dipole.f orbanly_part_f.f smatchk2.f \
  frprmn_tm12_check_Vext_Avec_v4.f pack.f tdep.f vpj_gen.f \
  electf4_Vext_Avec.f gga_lib_3_PBE.f \
  pspw_tm11_Vext_Avec_v4_alloc.f tmevl10_Avec_v4.f bannerTDDFT.f \
  fft_fftw.f omp_clock.f fftw_threads_fwrap.o \
  -L"$FFTW_ROOT/lib" $LDFLAGS $FFTW_LIBS
