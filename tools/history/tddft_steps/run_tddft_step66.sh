#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LABEL=nvhpc_cufft_1rank_02_STEP66_VPJ_KERNEL_D2H_01 \
SUMMARY_TITLE="FPSEID21 STEP66 VPJ KERNEL D2H SUMMARY" \
  exec "$SCRIPT_DIR/../../run_tddft_frprmn_diagnostic.sh"
