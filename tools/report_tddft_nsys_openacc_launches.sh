#!/bin/sh
set -eu

# Report the actual Grid/Block dimensions of NVHPC OpenACC kernels already
# captured by Nsight Systems. This is post-processing only: it does not build
# or execute TDDFT and it excludes cuFFT library kernels.
#
# Usage:
#   ./tools/report_tddft_nsys_openacc_launches.sh \
#     ./run/nsys_archives/<STEP116_LABEL>

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 NSYS_ARCHIVE_DIR_OR_REPORT" >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET=$1
NSYS=${NSYS:-nsys}
MAX_ROWS=${MAX_ROWS:-40}

case "$TARGET" in
  *.nsys-rep)
    REPORT=$TARGET
    ARCHIVE_DIR=$(dirname -- "$REPORT")
    ;;
  *)
    ARCHIVE_DIR=$TARGET
    REPORT=$ARCHIVE_DIR/tddft_nsys.nsys-rep
    ;;
esac

if [ ! -f "$REPORT" ]; then
  echo "ERROR: Nsight Systems report does not exist: $REPORT" >&2
  exit 1
fi

REPORT=$(CDPATH= cd -- "$(dirname -- "$REPORT")" && pwd)/$(basename -- "$REPORT")
ARCHIVE_DIR=$(CDPATH= cd -- "$ARCHIVE_DIR" && pwd)
SQLITE=$ARCHIVE_DIR/tddft_nsys.sqlite

if [ ! -f "$SQLITE" ]; then
  if ! command -v "$NSYS" >/dev/null 2>&1; then
    echo "ERROR: SQLite is absent and Nsight Systems was not found: $NSYS" >&2
    exit 1
  fi
  echo "Exporting existing Nsight report to SQLite (no GPU execution):"
  echo "  $SQLITE"
  "$NSYS" export --type sqlite --output "$SQLITE" "$REPORT"
fi

python3 "$SCRIPT_DIR/report_tddft_nsys_openacc_launches.py" \
  --max-rows "$MAX_ROWS" "$SQLITE"
