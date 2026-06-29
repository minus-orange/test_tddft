#!/bin/sh
set -eu

# Intel/GNU/NVIDIA Fortran build for the FPSEID21 CG executable.
#
# Optional environment:
#   FC      Fortran compiler. Default: ifort
#   FFLAGS  Fortran flags. Default depends on FC.
#   LDFLAGS Additional linker flags.

FC=${FC:-ifort}

FC_PROBE="$FC
$("$FC" --version 2>/dev/null || true)"

if printf '%s\n' "$FC_PROBE" | grep -Eiq 'nvfortran|pgfortran'; then
    FFLAGS=${FFLAGS:-"-O2 -mp -Msave -Mlarge_arrays"}
    MAIN_SRC=${MAIN_SRC:-cg_main_gga_df_omp_YY_allct_gnu.f}
    RARR4_SRC=${RARR4_SRC:-rarr4_gnu.f}
elif printf '%s\n' "$FC_PROBE" | grep -Eiq 'gfortran|GNU Fortran'; then
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    MAIN_SRC=${MAIN_SRC:-cg_main_gga_df_omp_YY_allct_gnu.f}
    RARR4_SRC=${RARR4_SRC:-rarr4_gnu.f}
else
    FFLAGS=${FFLAGS:-"-O3 -mcmodel=medium -qopenmp -traceback"}
    MAIN_SRC=${MAIN_SRC:-cg_main_gga_df_omp_YY_allct.f}
    RARR4_SRC=${RARR4_SRC:-rarr4.f}
fi
LDFLAGS=${LDFLAGS:-}
OUT=${OUT:-cg_exe}

set -x
"$FC" $FFLAGS \
  -o "$OUT" \
  eigsystm.F90 "$MAIN_SRC" dosgen.f \
  newfft.f orbanly_part_f.f cg_inputs3.f "$RARR4_SRC" \
  potextr.f pack.f smatchk2.f gga_lib_3_PBE.f \
  omp_clock.f bannerCG.f \
  $LDFLAGS
