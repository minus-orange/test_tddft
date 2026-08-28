#!/bin/sh
set -eu

# Read-only cross-platform comparison for the official diamond cb3x3x3 case.
# With one argument, compare the fixed 8592+ diagnostic against that path.
# Each path may name a run directory or its TDDFT output file.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

DEFAULT_REFERENCE=$ROOT_DIR/run/benchmarks/cb3x3x3/platforms/8592p_spr10/runs/cb3x3x3_8592p_spr10_32mpi_4omp_100step_diag_01
EXPECTED_STEPS=${EXPECTED_STEPS:-100}
EXPECTED_ATOMS=${EXPECTED_ATOMS:-216}
REFERENCE_PLATFORM=${REFERENCE_PLATFORM:-XEON_8592P_32MPI_4OMP}
TEST_PLATFORM=${TEST_PLATFORM:-NEC_VE}

usage() {
  cat <<'EOF'
Usage:
  ./tools/compare_cb3x3x3_platform_results.sh TEST_PATH
  ./tools/compare_cb3x3x3_platform_results.sh REFERENCE_PATH TEST_PATH

Paths may be run directories or TDDFT output files. With one path, the
reference is the fixed Xeon 8592+ 100-step diagnostic run.

Optional environment:
  EXPECTED_STEPS       default: 100
  EXPECTED_ATOMS       default: 216
  REFERENCE_PLATFORM   label printed for the reference
  TEST_PLATFORM        label printed for the test platform
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

positive_integer() {
  case "$1" in
    ''|*[!0-9]*|0) fail "$2 must be a positive integer" ;;
  esac
}

resolve_output() {
  supplied=$1
  if [ -d "$supplied" ]; then
    for name in dia-cb3x3x3_tm.out tddft.out; do
      if [ -s "$supplied/$name" ]; then
        printf '%s\n' "$supplied/$name"
        return 0
      fi
    done
    fail "no nonempty TDDFT output found in directory: $supplied"
  fi
  [ -s "$supplied" ] || fail "TDDFT output is missing or empty: $supplied"
  printf '%s\n' "$supplied"
}

find_error_log() {
  output=$1
  directory=$(CDPATH= cd -- "$(dirname -- "$output")" && pwd)
  stem=${output%.out}
  for candidate in "$stem.err" "$directory/stderr" "$directory/tddft.err"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' ''
}

run_check() {
  output=$1
  error_log=$2
  set -- python3 "$SCRIPT_DIR/check_tddft_result.py" check "$output" \
    --expected-steps "$EXPECTED_STEPS" --expected-atoms "$EXPECTED_ATOMS" \
    --no-require-profile
  if [ -n "$error_log" ]; then
    set -- "$@" --err "$error_log"
  fi
  "$@"
}

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac

if [ "$#" -eq 1 ]; then
  reference_path=$DEFAULT_REFERENCE
  test_path=$1
elif [ "$#" -eq 2 ]; then
  reference_path=$1
  test_path=$2
else
  usage >&2
  exit 2
fi

positive_integer "$EXPECTED_STEPS" EXPECTED_STEPS
positive_integer "$EXPECTED_ATOMS" EXPECTED_ATOMS

reference_output=$(resolve_output "$reference_path")
test_output=$(resolve_output "$test_path")
reference_error=$(find_error_log "$reference_output")
test_error=$(find_error_log "$test_output")

echo "FPSEID21_CB3X3X3_PLATFORM_COMPARE_BEGIN"
echo "reference_platform=$REFERENCE_PLATFORM"
echo "reference_output=$reference_output"
echo "test_platform=$TEST_PLATFORM"
echo "test_output=$test_output"
echo "expected_steps=$EXPECTED_STEPS"
echo "expected_atoms=$EXPECTED_ATOMS"
echo "input_identity=OUTPUT_OBSERVABLES_ONLY"
echo "comparison_scope=DIAGNOSTIC_ONLY"
echo "provenance_gate=INCOMPLETE"

if ! reference_summary=$(run_check "$reference_output" "$reference_error" 2>&1); then
  printf '%s\n' "$reference_summary"
  fail "reference normal check failed; performance comparison is blocked"
fi
echo "REFERENCE_NORMAL_CHECK_BEGIN"
printf '%s\n' "$reference_summary"
echo "REFERENCE_NORMAL_CHECK_END"

if ! test_summary=$(run_check "$test_output" "$test_error" 2>&1); then
  printf '%s\n' "$test_summary"
  fail "test normal check failed; performance comparison is blocked"
fi
echo "TEST_NORMAL_CHECK_BEGIN"
printf '%s\n' "$test_summary"
echo "TEST_NORMAL_CHECK_END"

set -- python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
  "$reference_output" "$test_output" \
  --expected-steps "$EXPECTED_STEPS" --expected-atoms "$EXPECTED_ATOMS" \
  --no-require-profile
if [ -n "$reference_error" ]; then
  set -- "$@" --ref-err "$reference_error"
fi
if [ -n "$test_error" ]; then
  set -- "$@" --test-err "$test_error"
fi
if ! comparison=$({ "$@"; } 2>&1); then
  printf '%s\n' "$comparison"
  fail "relaxed comparison failed; performance comparison is blocked"
fi
echo "RELAXED_COMPARE_BEGIN"
printf '%s\n' "$comparison"
echo "RELAXED_COMPARE_END"

reference_wall=$(printf '%s\n' "$reference_summary" | awk '
  /steps:/ {
    for (i=1; i<NF; i++) if ($i == "wall_sec:") value=$(i+1)
  }
  END {print value}
')
test_wall=$(printf '%s\n' "$test_summary" | awk '
  /steps:/ {
    for (i=1; i<NF; i++) if ($i == "wall_sec:") value=$(i+1)
  }
  END {print value}
')
[ -n "$reference_wall" ] || fail "reference wall time was not parsed"
[ -n "$test_wall" ] || fail "test wall time was not parsed"

awk -v ref="$reference_wall" -v test="$test_wall" \
    -v ref_name="$REFERENCE_PLATFORM" -v test_name="$TEST_PLATFORM" '
  BEGIN {
    print "PLATFORM_PERFORMANCE_COMPARISON"
    printf "reference_wall_sec=%.11f\n", ref
    printf "test_wall_sec=%.11f\n", test
    printf "test_over_reference_ratio=%.9f\n", test / ref
    if (test < ref) {
      printf "faster_platform=%s\n", test_name
      printf "speedup=%.9f\n", ref / test
      printf "wall_reduction_pct=%.6f\n", (ref - test) / ref * 100.0
    } else if (ref < test) {
      printf "faster_platform=%s\n", ref_name
      printf "speedup=%.9f\n", test / ref
      printf "wall_reduction_pct=%.6f\n", (test - ref) / test * 100.0
    } else {
      print "faster_platform=TIE"
      print "speedup=1.000000000"
      print "wall_reduction_pct=0.000000"
    }
  }
'

echo "normal_checks=PASS"
echo "relaxed_compare=PASS"
echo "provenance_gate=INCOMPLETE"
echo "baseline=NOT_APPLICABLE"
echo "FPSEID21_CB3X3X3_PLATFORM_COMPARE_END"
