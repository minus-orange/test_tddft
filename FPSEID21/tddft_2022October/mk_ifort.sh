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
#   BUILD_REPORT  Set to 1 to print more build details and add compiler reports.
#   REPORT_FLAGS   Extra compiler report flags when BUILD_REPORT=1.
#   FPSEID_STEP_A_DIAGNOSTIC  Set to 1 for bounded OpenACC diagnostics.
#   FFTW_LIBS  FFTW libraries. Default: -lfftw3_omp -lfftw3
#   FFT_BACKEND FFT implementation. Default: fftw. Set to cufft for GPU FFT.
#   CUFFT_LIBS  cuFFT libraries when FFT_BACKEND=cufft.
#   CUDA_ROOT   CUDA installation prefix when FFT_BACKEND=cufft.
#   CUDA_RUNTIME_INCLUDE  directory containing cuda_runtime.h.
#   CUFFT_INCLUDE         directory containing cufft.h.
#   CUDA_RUNTIME_LIB      directory containing libcudart.so.
#   CUFFT_LIB             directory containing libcufft.so.

FC=${FC:-mpiifort}
CC=${CC:-mpicc}
FFTW_ROOT=${FFTW_ROOT:-}
FFT_BACKEND=${FFT_BACKEND:-fftw}
BUILD_REPORT=${BUILD_REPORT:-0}
FPSEID_STEP_A_DIAGNOSTIC=${FPSEID_STEP_A_DIAGNOSTIC:-0}

FC_PROBE="$FC
$("$FC" --version 2>/dev/null || true)
$("$FC" -show 2>/dev/null || true)
$("$FC" --showme:command 2>/dev/null || true)"

if printf '%s\n' "$FC_PROBE" | grep -Eiq 'nvfortran|pgfortran'; then
    FC_FAMILY=nvhpc
    PREPROCESS_FLAG=-Mpreprocess
    FFLAGS=${FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
    REPORT_FLAGS=${REPORT_FLAGS:-"-Minfo=accel -Minfo=mp"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE.f}
    RARR3_SRC=${RARR3_SRC:-rarr3.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc.f}
elif printf '%s\n' "$FC_PROBE" | grep -Eiq 'gfortran|GNU Fortran'; then
    FC_FAMILY=gnu
    PREPROCESS_FLAG=-cpp
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    REPORT_FLAGS=${REPORT_FLAGS:-"-fopt-info-optimized -fopt-info-vec"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE_gnu.f}
    RARR3_SRC=${RARR3_SRC:-rarr3_gnu.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs_gnu.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc_gnu.f}
else
    FC_FAMILY=intel
    PREPROCESS_FLAG=-fpp
    FFLAGS=${FFLAGS:-"-O3 -traceback -qopenmp"}
    REPORT_FLAGS=${REPORT_FLAGS:-"-qopt-report=2"}
    LIB4_SRC=${LIB4_SRC:-lib4_ASL_2_check_Vext_SXACE.f}
    RARR3_SRC=${RARR3_SRC:-rarr3.f}
    TM_INPUTS_SRC=${TM_INPUTS_SRC:-tm_inputs.f}
    PSPW_SRC=${PSPW_SRC:-pspw_tm11_Vext_Avec_v4_alloc.f}
fi
if [ "$BUILD_REPORT" = 1 ]; then
    FFLAGS="$FFLAGS $REPORT_FLAGS"
fi
CFLAGS=${CFLAGS:-"-O2"}
LDFLAGS=${LDFLAGS:-}
FFTW_LIBS=${FFTW_LIBS:-"-lfftw3_omp -lfftw3"}
CUFFT_LIBS=${CUFFT_LIBS:-"-lcufft -lcudart"}

case "$FPSEID_STEP_A_DIAGNOSTIC" in
  0|1) ;;
  *)
    echo "ERROR: FPSEID_STEP_A_DIAGNOSTIC must be 0 or 1." >&2
    exit 1
    ;;
esac

STEPA_DEFINE=
STEPA_SRC=
STEPA_OBJS=
if [ "$FPSEID_STEP_A_DIAGNOSTIC" = 1 ]; then
  if [ "$FC_FAMILY" != nvhpc ]; then
    echo "ERROR: FPSEID Step A diagnostics require an NVHPC Fortran compiler." >&2
    exit 1
  fi
  case " $FFLAGS " in
    *" -acc "*|*" -acc="*) ;;
    *)
      echo "ERROR: FPSEID Step A diagnostics require -acc in FFLAGS." >&2
      exit 1
      ;;
  esac
  CC_PROBE="$CC
$($CC --version 2>/dev/null || true)"
  if ! printf '%s\n' "$CC_PROBE" | grep -Eiq '(^|[/[:space:]])nvc([[:space:]]|$)|NVIDIA'; then
    echo "ERROR: FPSEID Step A diagnostics require nvc as CC." >&2
    exit 1
  fi
  if ! "$FC" $FFLAGS $PREPROCESS_FLAG -c stepa_default_int_probe.F90 \
       -o stepa_default_int_probe.o; then
    rm -f stepa_default_int_probe.o
    echo "ERROR: FPSEID Step A requires default integer == c_int" >&2
    exit 1
  fi
  rm -f stepa_default_int_probe.o
  STEPA_DEFINE=-DFPSEID_STEP_A_DIAGNOSTIC=1
  STEPA_SRC=mod_stepa_diag.F90
  STEPA_OBJS=fpseid_stepa_acc_diag.o
fi

add_link_dir() {
  dir=$1
  if [ -d "$dir" ]; then
    case " $CUFFT_LINK_DIRS " in
      *" -L$dir "*) ;;
      *) CUFFT_LINK_DIRS="$CUFFT_LINK_DIRS -L$dir" ;;
    esac
  fi
}

add_lib_dirs_from_include() {
  inc=$1
  [ -n "$inc" ] || return 0
  [ -d "$inc" ] || return 0

  parent=$(CDPATH= cd -- "$inc/.." && pwd)
  add_link_dir "$parent/lib64"
  add_link_dir "$parent/lib"
}

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
    CUFFT_LINK_DIRS=
    if [ -n "${CUDA_ROOT:-}" ]; then
      if [ -f "$CUDA_ROOT/include/cuda_runtime.h" ] ||
         [ -f "$CUDA_ROOT/include/cufft.h" ]; then
        FFT_INCLUDE="$FFT_INCLUDE -I$CUDA_ROOT/include"
        add_lib_dirs_from_include "$CUDA_ROOT/include"
      fi
      if [ -d "$CUDA_ROOT/lib64" ]; then
        add_link_dir "$CUDA_ROOT/lib64"
      fi
      add_link_dir "$CUDA_ROOT/lib"
    fi
    if [ -n "${CUDA_RUNTIME_INCLUDE:-}" ]; then
      FFT_INCLUDE="$FFT_INCLUDE -I$CUDA_RUNTIME_INCLUDE"
      add_lib_dirs_from_include "$CUDA_RUNTIME_INCLUDE"
    fi
    if [ -n "${CUFFT_INCLUDE:-}" ] &&
       [ "${CUFFT_INCLUDE:-}" != "${CUDA_RUNTIME_INCLUDE:-}" ]; then
      FFT_INCLUDE="$FFT_INCLUDE -I$CUFFT_INCLUDE"
      add_lib_dirs_from_include "$CUFFT_INCLUDE"
    fi
    if [ -n "${CUDA_RUNTIME_LIB:-}" ]; then
      add_link_dir "$CUDA_RUNTIME_LIB"
    fi
    if [ -n "${CUFFT_LIB:-}" ]; then
      add_link_dir "$CUFFT_LIB"
    fi
    FFT_SRC=fft_cufft.f
    FFT_OBJS=fpseid_cufft_wrap.o
    FFT_LINK="$CUFFT_LINK_DIRS $CUFFT_LIBS"
    ;;
  *)
    echo "ERROR: unknown FFT_BACKEND: $FFT_BACKEND" >&2
    echo "Use FFT_BACKEND=fftw or FFT_BACKEND=cufft." >&2
    exit 1
    ;;
esac

echo "TDDFT source selection:"
echo "  LIB4_SRC=$LIB4_SRC"
echo "  RARR3_SRC=$RARR3_SRC"
echo "  TM_INPUTS_SRC=$TM_INPUTS_SRC"
echo "  PSPW_SRC=$PSPW_SRC"
echo "  FFT_BACKEND=$FFT_BACKEND"
echo "  FC=$FC"
echo "  CC=$CC"
echo "  FFLAGS=$FFLAGS"
echo "  CFLAGS=$CFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo "  PREPROCESS_FLAG=$PREPROCESS_FLAG"
echo "  FPSEID_STEP_A_DIAGNOSTIC=$FPSEID_STEP_A_DIAGNOSTIC"
echo "  FFT_INCLUDE=$FFT_INCLUDE"
echo "  FFT_LINK=$FFT_LINK"
if [ "$BUILD_REPORT" = 1 ]; then
  echo "  BUILD_REPORT=1"
  echo "  REPORT_FLAGS=$REPORT_FLAGS"
fi

set -x
case "$FFT_BACKEND" in
  fftw)
    "$CC" $CFLAGS $FFT_INCLUDE -c fftw_threads_fwrap.c \
      -o fftw_threads_fwrap.o
    ;;
  cufft)
    "$CC" $CFLAGS $FFT_INCLUDE -c fpseid_cufft_wrap.c \
      -o fpseid_cufft_wrap.o
    ;;
esac
if [ "$FPSEID_STEP_A_DIAGNOSTIC" = 1 ]; then
  "$CC" $CFLAGS -acc -c fpseid_stepa_acc_diag.c \
    -o fpseid_stepa_acc_diag.o
fi
"$FC" $FFLAGS \
  $PREPROCESS_FLAG $STEPA_DEFINE \
  $FFT_INCLUDE \
  -o tddft_exe \
  mod_timer.f90 $STEPA_SRC cpu_block.f prof_timer.f "$LIB4_SRC" \
  "$RARR3_SRC" "$TM_INPUTS_SRC" \
  rexgenDummy.f dipole.f orbanly_part_f.f smatchk2.f \
  frprmn_tm12_check_Vext_Avec_v4.f pack.f tdep.f vpj_gen.f \
  electf4_Vext_Avec.f gga_lib_3_PBE.f \
  "$PSPW_SRC" tmevl10_Avec_v4.f bannerTDDFT.f \
  "$FFT_SRC" omp_clock.f $FFT_OBJS $STEPA_OBJS \
  $LDFLAGS $FFT_LINK
