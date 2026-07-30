#!/bin/sh
set -u

# Check the most recent unarchived x86 Si111-H result in one command.
#
# Usage:
#   ./tools/check_tddft_x86_result.sh
#   ./tools/check_tddft_x86_result.sh /path/to/Si111-H_x86

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [RUN_DIR]" >&2
  exit 2
fi

RUN_DIR=${1:-"${RUN_DIR:-$ROOT_DIR/run/Si111-H_x86}"}
TDDFT_OUTPUT=${TDDFT_OUTPUT:-"$RUN_DIR/Si111-H_tm.out"}
TDDFT_ERR=${TDDFT_ERR:-"$RUN_DIR/Si111-H_tm.err"}
EXPECTED_STEPS=${EXPECTED_STEPS:-100}

if [ ! -f "$TDDFT_OUTPUT" ]; then
  echo "ERROR: TDDFT output is missing: $TDDFT_OUTPUT" >&2
  exit 1
fi
if [ ! -f "$TDDFT_ERR" ]; then
  echo "ERROR: TDDFT stderr is missing: $TDDFT_ERR" >&2
  exit 1
fi

status=0
normal=FAIL
relaxed=FAIL

echo "FPSEID21_X86_RESULT_CHECK_BEGIN"
echo "run_dir=$RUN_DIR"
echo "expected_steps=$EXPECTED_STEPS"

if python3 "$SCRIPT_DIR/check_tddft_result.py" check \
  "$TDDFT_OUTPUT" --err "$TDDFT_ERR" \
  --expected-steps "$EXPECTED_STEPS"; then
  normal=PASS
else
  status=1
fi

if python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
  "$TDDFT_OUTPUT" --test-err "$TDDFT_ERR" \
  --expected-steps "$EXPECTED_STEPS"; then
  relaxed=PASS
else
  status=1
fi

wall=$(awk '/steps took/ { value=$(NF-1) } END {
  if (value == "") print "not_found"
  else print value
}' "$TDDFT_OUTPUT")

echo "normal_check=$normal"
echo "relaxed_compare=$relaxed"
echo "wall_sec=$wall"

if [ "$status" -ne 0 ]; then
  echo "tddft_err_tail_begin"
  tail -n 40 "$TDDFT_ERR"
  echo "tddft_err_tail_end"
fi

echo "FPSEID21_X86_RESULT_CHECK_END"
exit "$status"
