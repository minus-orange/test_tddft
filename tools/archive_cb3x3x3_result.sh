#!/bin/sh
set -eu

# Archive a cb3x3x3 TDDFT result under its independent series and require a
# same-input reference. The historical Si111-H reference is never used.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
RUN_DIR=${RUN_DIR:-"$BENCHMARK_ROOT/work/tddft_600K"}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$BENCHMARK_ROOT/archives"}
EXPECTED_STEPS=${EXPECTED_STEPS:-1000}
TDDFT_INPUT=${TDDFT_INPUT:-"dia-cb3x3x3_tm.in_${EXPECTED_STEPS}steps"}
TDDFT_OUTPUT=${TDDFT_OUTPUT:-dia-cb3x3x3_tm.out}
TDDFT_ERR=${TDDFT_ERR:-dia-cb3x3x3_tm.err}

case "$EXPECTED_STEPS" in
  40000)
    REFERENCE_OUTPUT=${REFERENCE_OUTPUT:-"$BENCHMARK_ROOT/official/600K/dia-cb3x3x3_tm.out_AOBA-S"}
    ;;
  *)
    if [ -z "${REFERENCE_OUTPUT:-}" ]; then
      echo "ERROR: REFERENCE_OUTPUT is required for a non-40000-step result." >&2
      echo "The Si111-H reference must not be used for cb3x3x3." >&2
      exit 1
    fi
    ;;
esac

if [ -z "${LABEL:-}" ]; then
  echo "ERROR: set a unique LABEL for the cb3x3x3 platform series." >&2
  exit 1
fi
if [ ! -f "$REFERENCE_OUTPUT" ]; then
  echo "ERROR: reference output does not exist: $REFERENCE_OUTPUT" >&2
  exit 1
fi
for required in \
  "$TDDFT_INPUT" "$TDDFT_OUTPUT" "$TDDFT_ERR" \
  SOURCE_MANIFEST.env STATE_MANIFEST.sha256 TR.C95g_asci \
  rh.dia-cb3x3x3 wf_fft.dia-cb3x3x3
do
  if [ ! -f "$RUN_DIR/$required" ]; then
    echo "ERROR: required run file does not exist: $RUN_DIR/$required" >&2
    exit 1
  fi
done

ARCHIVE_ROOT=$ARCHIVE_ROOT \
TDDFT_INPUT=$TDDFT_INPUT TDDFT_OUTPUT=$TDDFT_OUTPUT TDDFT_ERR=$TDDFT_ERR \
TDDFT_REFERENCE=$REFERENCE_OUTPUT EXPECTED_STEPS=$EXPECTED_STEPS \
ARCHIVE_EXTRA_PATHS="SOURCE_MANIFEST.env STATE_MANIFEST.sha256 TR.C95g_asci rh.dia-cb3x3x3 wf_fft.dia-cb3x3x3" \
LABEL=$LABEL "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

archive_dir=$ARCHIVE_ROOT/$LABEL
python3 "$SCRIPT_DIR/check_tddft_result.py" check \
  "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
  --expected-steps "$EXPECTED_STEPS"
python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
  "$REFERENCE_OUTPUT" "$archive_dir/tddft.out" \
  --test-err "$archive_dir/tddft.err" \
  --expected-steps "$EXPECTED_STEPS" --no-require-profile

echo "CB3X3X3_ARCHIVE_PASS"
echo "archive=$archive_dir"
echo "reference=$REFERENCE_OUTPUT"
echo "expected_steps=$EXPECTED_STEPS"
