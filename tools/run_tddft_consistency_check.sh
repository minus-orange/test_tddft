#!/bin/sh
set -eu

# Run the Si111-H sample twice and compare TDDFT observables. The first run is
# the reference, usually one MPI rank. The second run uses the rank count under
# test. Compilers, MPI launchers, and executable paths are inherited through the
# same environment variables supported by run_si111_h_sample.sh.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_100steps}
REF_NPROCS=${REF_NPROCS:-1}
TEST_NPROCS=${TEST_NPROCS:-32}
RUN_BASE=${RUN_BASE:-"$ROOT_DIR/run/consistency"}
REF_RUN_DIR=${REF_RUN_DIR:-"$RUN_BASE/np$REF_NPROCS"}
TEST_RUN_DIR=${TEST_RUN_DIR:-"$RUN_BASE/np$TEST_NPROCS"}

ENERGY_ATOL=${ENERGY_ATOL:-1e-5}
FORCE_ATOL=${FORCE_ATOL:-1e-5}
POSITION_ATOL=${POSITION_ATOL:-1e-6}
VELOCITY_ATOL=${VELOCITY_ATOL:-1e-6}

mkdir -p "$RUN_BASE"

echo "Preparing reference run directory: $REF_RUN_DIR"
RUN_DIR="$REF_RUN_DIR" "$SCRIPT_DIR/prepare_si111_h_sample.sh"

echo "Running reference: NPROCS=$REF_NPROCS TDDFT_INPUT=$TDDFT_INPUT"
RUN_DIR="$REF_RUN_DIR" NPROCS="$REF_NPROCS" TDDFT_INPUT="$TDDFT_INPUT" \
  "$SCRIPT_DIR/run_si111_h_sample.sh"

echo "Preparing test run directory: $TEST_RUN_DIR"
RUN_DIR="$TEST_RUN_DIR" "$SCRIPT_DIR/prepare_si111_h_sample.sh"

echo "Running test: NPROCS=$TEST_NPROCS TDDFT_INPUT=$TDDFT_INPUT"
RUN_DIR="$TEST_RUN_DIR" NPROCS="$TEST_NPROCS" TDDFT_INPUT="$TDDFT_INPUT" \
  "$SCRIPT_DIR/run_si111_h_sample.sh"

python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
  "$REF_RUN_DIR/Si111-H_tm.out" \
  "$TEST_RUN_DIR/Si111-H_tm.out" \
  --ref-err "$REF_RUN_DIR/Si111-H_tm.err" \
  --test-err "$TEST_RUN_DIR/Si111-H_tm.err" \
  --energy-atol "$ENERGY_ATOL" \
  --force-atol "$FORCE_ATOL" \
  --position-atol "$POSITION_ATOL" \
  --velocity-atol "$VELOCITY_ATOL"
