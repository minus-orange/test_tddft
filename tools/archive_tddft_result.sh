#!/bin/sh
set -eu

# Archive one FPSEID21 TDDFT run directory for later result checks and
# cross-platform comparisons.
#
# The default archive root is under run/ so large density/wavefunction files do
# not get added to git accidentally.
#
# Usage:
#   ./tools/archive_tddft_result.sh RUN_DIR
#   LABEL=nvhpc_cufft_1gpu_1rank ./tools/archive_tddft_result.sh run/Si111-H_nvhpc
#   TDDFT_OUTPUT=Si111-H_tm.out_100steps_gpu_1rank \
#     TDDFT_ERR=Si111-H_tm_gpu_1rank.err \
#     ./tools/archive_tddft_result.sh run/Si111-H_nvhpc
#
# Environment:
#   ARCHIVE_ROOT  default: <repo>/run/tddft_archives
#   LABEL         default: <run-dir-name>_<timestamp>
#   TDDFT_INPUT   default: Si111-H_tm.in_100steps
#   TDDFT_OUTPUT  default: auto-detected TDDFT output log
#   TDDFT_ERR     default: auto-detected stderr log when present
#   TDDFT_REFERENCE  optional explicit comparison reference
#   EXPECTED_STEPS   optional expected step count for printed check commands
#   ARCHIVE_EXTRA_PATHS  optional space-separated run-relative files

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 RUN_DIR" >&2
  exit 2
fi

RUN_DIR=$1
if [ ! -d "$RUN_DIR" ]; then
  echo "ERROR: run directory does not exist: $RUN_DIR" >&2
  exit 1
fi

ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_100steps}
timestamp=$(date '+%Y%m%d_%H%M%S')
run_name=$(basename "$RUN_DIR")
LABEL=${LABEL:-"${run_name}_${timestamp}"}
ARCHIVE_DIR=$ARCHIVE_ROOT/$LABEL

choose_existing() {
  for name in "$@"; do
    if [ -f "$RUN_DIR/$name" ]; then
      printf '%s\n' "$name"
      return 0
    fi
  done
  return 1
}

TDDFT_OUTPUT=${TDDFT_OUTPUT:-$(choose_existing \
  Si111-H_tm.out_100steps_gpu_1rank \
  Si111-H_tm.out_100steps_5MPI \
  Si111-H_tm.out_100steps_4MPI \
  Si111-H_tm.out_100steps_2MPI \
  Si111-H_tm.out_100steps \
  Si111-H_tm.out \
  || true)}

TDDFT_ERR=${TDDFT_ERR:-$(choose_existing \
  Si111-H_tm_gpu_1rank.err \
  Si111-H_tm_5MPI.err \
  Si111-H_tm_4MPI.err \
  Si111-H_tm_2MPI.err \
  Si111-H_tm.err \
  || true)}

if [ -z "$TDDFT_OUTPUT" ]; then
  echo "ERROR: could not auto-detect TDDFT output in $RUN_DIR." >&2
  echo "Set TDDFT_OUTPUT=<file-name> explicitly." >&2
  exit 1
fi

if [ ! -f "$RUN_DIR/$TDDFT_OUTPUT" ]; then
  echo "ERROR: TDDFT output does not exist: $RUN_DIR/$TDDFT_OUTPUT" >&2
  exit 1
fi

if [ ! -f "$RUN_DIR/$TDDFT_INPUT" ]; then
  echo "ERROR: TDDFT input does not exist: $RUN_DIR/$TDDFT_INPUT" >&2
  exit 1
fi

if [ -e "$ARCHIVE_DIR" ]; then
  echo "ERROR: archive directory already exists: $ARCHIVE_DIR" >&2
  exit 1
fi

mkdir -p "$ARCHIVE_DIR"

copy_path() {
  rel=$1
  src=$RUN_DIR/$rel
  if [ -L "$src" ]; then
    cp -P "$src" "$ARCHIVE_DIR/$rel"
  elif [ -f "$src" ]; then
    cp -p "$src" "$ARCHIVE_DIR/$rel"
  fi
}

for rel in \
  "$TDDFT_INPUT" \
  "$TDDFT_OUTPUT" \
  size.dat sym.C1 laser.dat \
  Eext Etot Avec Ework \
  rh.Si111-H rh.Si111-H_new rh.Si111-H_new.sd \
  wf_fft.Si111-H wf_fft.Si111-H_new wf_real.Si111-H \
  TR.Si93g_asci TR.H99g_asc TR.Si93e_asci \
  fort.18 fort.20 fort.22 fort.23 fort.24 fort.28 fort.32 \
  fort.41 fort.42 fort.46 fort.53 fort.54 fort.55 fort.60 \
  fort.62 fort.88 fort.90 fort.91 fort.92 fort.93 fort.94
do
  copy_path "$rel"
done

for rel in ${ARCHIVE_EXTRA_PATHS:-}; do
  copy_path "$rel"
done

if [ -n "$TDDFT_ERR" ] && [ -f "$RUN_DIR/$TDDFT_ERR" ]; then
  copy_path "$TDDFT_ERR"
fi

cp -p "$RUN_DIR/$TDDFT_OUTPUT" "$ARCHIVE_DIR/tddft.out"
if [ -n "$TDDFT_ERR" ] && [ -f "$RUN_DIR/$TDDFT_ERR" ]; then
  cp -p "$RUN_DIR/$TDDFT_ERR" "$ARCHIVE_DIR/tddft.err"
fi

{
  echo "FPSEID21 TDDFT archive"
  echo "created_at=$timestamp"
  echo "source_run_dir=$RUN_DIR"
  echo "archive_dir=$ARCHIVE_DIR"
  echo "tddft_input=$TDDFT_INPUT"
  echo "tddft_output=$TDDFT_OUTPUT"
  echo "tddft_err=$TDDFT_ERR"
  echo "tddft_reference=${TDDFT_REFERENCE:-}"
  echo "expected_steps=${EXPECTED_STEPS:-}"
  echo
  echo "Check archived result:"
  check_steps=
  if [ -n "${EXPECTED_STEPS:-}" ]; then
    check_steps=" --expected-steps $EXPECTED_STEPS"
  fi
  if [ -f "$ARCHIVE_DIR/tddft.err" ]; then
    echo "  python3 ./tools/check_tddft_result.py check \"$ARCHIVE_DIR/tddft.out\" --err \"$ARCHIVE_DIR/tddft.err\"$check_steps"
  else
    echo "  python3 ./tools/check_tddft_result.py check \"$ARCHIVE_DIR/tddft.out\"$check_steps"
  fi
  echo
  if [ -n "${TDDFT_REFERENCE:-}" ]; then
    echo "Compare archived result with explicit reference:"
    if [ -f "$ARCHIVE_DIR/tddft.err" ]; then
      echo "  python3 ./tools/check_tddft_result.py compare \"$TDDFT_REFERENCE\" \"$ARCHIVE_DIR/tddft.out\" --test-err \"$ARCHIVE_DIR/tddft.err\"$check_steps --no-require-profile"
    else
      echo "  python3 ./tools/check_tddft_result.py compare \"$TDDFT_REFERENCE\" \"$ARCHIVE_DIR/tddft.out\"$check_steps --no-require-profile"
    fi
  else
    echo "Compare archived result with default GNU reference:"
    if [ -f "$ARCHIVE_DIR/tddft.err" ]; then
      echo "  python3 ./tools/check_tddft_result.py compare \"$ARCHIVE_DIR/tddft.out\" --test-err \"$ARCHIVE_DIR/tddft.err\"$check_steps"
    else
      echo "  python3 ./tools/check_tddft_result.py compare \"$ARCHIVE_DIR/tddft.out\"$check_steps"
    fi
  fi
  echo
  echo "Compare TDDFT input state with another archive/run directory:"
  echo "  TDDFT_INPUT=$TDDFT_INPUT ./tools/compare_tddft_run_inputs.sh REF_DIR \"$ARCHIVE_DIR\""
} > "$ARCHIVE_DIR/README.txt"

{
  echo "created_at=$timestamp"
  echo "source_run_dir=$RUN_DIR"
  echo "archive_dir=$ARCHIVE_DIR"
  echo "tddft_input=$TDDFT_INPUT"
  echo "tddft_output=$TDDFT_OUTPUT"
  echo "tddft_err=$TDDFT_ERR"
  echo "tddft_reference=${TDDFT_REFERENCE:-}"
  echo "expected_steps=${EXPECTED_STEPS:-}"
} > "$ARCHIVE_DIR/manifest.env"

echo "Archived TDDFT result:"
echo "  source:  $RUN_DIR"
echo "  output:  $TDDFT_OUTPUT"
if [ -n "$TDDFT_ERR" ]; then
  echo "  stderr:  $TDDFT_ERR"
fi
echo "  archive: $ARCHIVE_DIR"
echo
echo "Use:"
check_steps=
if [ -n "${EXPECTED_STEPS:-}" ]; then
  check_steps=" --expected-steps $EXPECTED_STEPS"
fi
if [ -f "$ARCHIVE_DIR/tddft.err" ]; then
  echo "  python3 ./tools/check_tddft_result.py check \"$ARCHIVE_DIR/tddft.out\" --err \"$ARCHIVE_DIR/tddft.err\"$check_steps"
else
  echo "  python3 ./tools/check_tddft_result.py check \"$ARCHIVE_DIR/tddft.out\"$check_steps"
fi
if [ -n "${TDDFT_REFERENCE:-}" ]; then
  if [ -f "$ARCHIVE_DIR/tddft.err" ]; then
    echo "  python3 ./tools/check_tddft_result.py compare \"$TDDFT_REFERENCE\" \"$ARCHIVE_DIR/tddft.out\" --test-err \"$ARCHIVE_DIR/tddft.err\"$check_steps --no-require-profile"
  else
    echo "  python3 ./tools/check_tddft_result.py compare \"$TDDFT_REFERENCE\" \"$ARCHIVE_DIR/tddft.out\"$check_steps --no-require-profile"
  fi
elif [ -f "$ARCHIVE_DIR/tddft.err" ]; then
  echo "  python3 ./tools/check_tddft_result.py compare \"$ARCHIVE_DIR/tddft.out\" --test-err \"$ARCHIVE_DIR/tddft.err\"$check_steps"
else
  echo "  python3 ./tools/check_tddft_result.py compare \"$ARCHIVE_DIR/tddft.out\"$check_steps"
fi
