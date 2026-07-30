#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LABEL=nvhpc_cufft_1rank_02_STEP65_VPJ_INTEGRAL_SPLIT_01 \
SUMMARY_TITLE="FPSEID21 STEP65 VPJ INTEGRAL SPLIT SUMMARY" \
  exec "$SCRIPT_DIR/../../run_tddft_frprmn_diagnostic.sh"
