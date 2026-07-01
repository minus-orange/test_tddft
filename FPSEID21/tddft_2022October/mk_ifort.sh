#!/bin/sh
set -eu

# Intel/GNU/NVIDIA MPI + FFTW3 build for the profiled FPSEID21 TDDFT executable.
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
#   FFT_BACKEND FFT implementation. Default: fftw. Set to cufft for GPU FFT.
#   CUFFT_LIBS  cuFFT libraries when FFT_BACKEND=cufft.

FC=${FC:-mpiifort}
CC=${CC:-mpicc}
FFTW_ROOT=${FFTW_ROOT:-}
FFT_BACKEND=${FFT_BACKEND:-fftw}

FC_PROBE="$FC
$("$FC" --version 2>/dev/null || true)
$("$FC" -show 2>/dev/null || true)
$("$FC" --showme:command 2>/dev/null || true)"

if printf '%s\n' "$FC_PROBE" | grep -Eiq 'nvfortran|pgfortran'; then
    FFLAGS=${FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE_gnu.f}
    RARR3_SRC=${RARR3_SRC:-rarr3_gnu.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs_gnu.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc_gnu.f}
elif printf '%s\n' "$FC_PROBE" | grep -Eiq 'gfortran|GNU Fortran'; then
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE_gnu.f}
    RARR3_SRC=${RARR3_SRC:-rarr3_gnu.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs_gnu.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc_gnu.f}
else
    FFLAGS=${FFLAGS:-"-O3 -traceback -qopenmp"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE.f}
    RARR3_SRC=${RARR3_SRC:-rarr3.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc.f}
fi
CFLAGS=${CFLAGS:-"-O2"}
LDFLAGS=${LDFLAGS:-}
FFTW_LIBS=${FFTW_LIBS:-"-lfftw3_omp -lfftw3"}
CUFFT_LIBS=${CUFFT_LIBS:-"-lcufft -lcudart"}

case "$FFT_BACKEND" in
  fftw)
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

    FFT_INCLUDE="-I$FFTW_ROOT/include"
    FFT_SRC=fft_fftw.f
    FFT_OBJS=fftw_threads_fwrap.o
    FFT_LINK="-L$FFTW_ROOT/lib $FFTW_LIBS"
    ;;
  cufft)
    FFT_INCLUDE=
    FFT_SRC=fft_cufft.f
    FFT_OBJS=fpseid_cufft_wrap.o
    FFT_LINK="$CUFFT_LIBS"
    ;;
  *)
    echo "ERROR: unknown FFT_BACKEND: $FFT_BACKEND" >&2
    echo "Use FFT_BACKEND=fftw or FFT_BACKEND=cufft." >&2
    exit 1
    ;;
esac

set -x
case "$FFT_BACKEND" in
  fftw)
    "$CC" $CFLAGS $FFT_INCLUDE -c fftw_threads_fwrap.c \
      -o fftw_threads_fwrap.o
    ;;
  cufft)
    "$CC" $CFLAGS -c fpseid_cufft_wrap.c -o fpseid_cufft_wrap.o
    ;;
esac
"$FC" $FFLAGS \
  $FFT_INCLUDE \
  -o tddft_exe \
  cpu_block.f prof_timer.f "$LIB4_SRC" \
  "$RARR3_SRC" "$TM_INPUTS_SRC" \
  rexgenDummy.f dipole.f orbanly_part_f.f smatchk2.f \
  frprmn_tm12_check_Vext_Avec_v4.f pack.f tdep.f vpj_gen.f \
  electf4_Vext_Avec.f gga_lib_3_PBE.f \
  "$PSPW_SRC" tmevl10_Avec_v4.f bannerTDDFT.f \
  "$FFT_SRC" omp_clock.f $FFT_OBJS \
  $LDFLAGS $FFT_LINK
