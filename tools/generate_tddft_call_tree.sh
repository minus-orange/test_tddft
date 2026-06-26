#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TDDFT_DIR="$ROOT_DIR/FPSEID21/tddft_2022October"

"$SCRIPT_DIR/generate_fortran_call_tree.py" \
  --root pspw \
  --output "$ROOT_DIR/docs/tddft_call_tree.md" \
  "$TDDFT_DIR/cpu_block.f" \
  "$TDDFT_DIR/prof_timer.f" \
  "$TDDFT_DIR/lib4_ASL_2_check_Vext_SXACE.f" \
  "$TDDFT_DIR/rarr3.f" \
  "$TDDFT_DIR/tm_inputs.f" \
  "$TDDFT_DIR/rexgenDummy.f" \
  "$TDDFT_DIR/dipole.f" \
  "$TDDFT_DIR/orbanly_part_f.f" \
  "$TDDFT_DIR/smatchk2.f" \
  "$TDDFT_DIR/frprmn_tm12_check_Vext_Avec_v4.f" \
  "$TDDFT_DIR/pack.f" \
  "$TDDFT_DIR/tdep.f" \
  "$TDDFT_DIR/vpj_gen.f" \
  "$TDDFT_DIR/electf4_Vext_Avec.f" \
  "$TDDFT_DIR/gga_lib_3_PBE.f" \
  "$TDDFT_DIR/pspw_tm11_Vext_Avec_v4_alloc.f" \
  "$TDDFT_DIR/tmevl10_Avec_v4.f" \
  "$TDDFT_DIR/bannerTDDFT.f" \
  "$TDDFT_DIR/fft_fftw.f"
