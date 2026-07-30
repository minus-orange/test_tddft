#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LABEL=nvhpc_cufft_1rank_02_STEP64_CURRENT_PART1TO5_01 \
SUMMARY_TITLE="FPSEID21 STEP64 CURRENT PART1TO5 SUMMARY" \
  exec "$SCRIPT_DIR/../../run_tddft_frprmn_diagnostic.sh"
