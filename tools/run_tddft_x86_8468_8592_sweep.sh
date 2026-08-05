#!/bin/sh
set -eu

# Build once, then screen full-physical-core MPI x OpenMP configurations on
# either a dual-socket Xeon Platinum 8468 or dual-socket Xeon Platinum 8592+.
# The default is one run per configuration. Set RUNS_PER_CONFIG=3 for a
# controlled three-run series after selecting the configurations to retain.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

CPU_PROFILE=${CPU_PROFILE:-auto}
RUNS_PER_CONFIG=${RUNS_PER_CONFIG:-1}
BUILD_MODE=${BUILD_MODE:-auto}
CONFIGS=${CONFIGS:-}

case "$CPU_PROFILE" in
  auto|8468|8592plus) ;;
  *)
    echo "ERROR: CPU_PROFILE must be auto, 8468, or 8592plus." >&2
    exit 2
    ;;
esac
case "$RUNS_PER_CONFIG" in
  1|3) ;;
  *)
    echo "ERROR: RUNS_PER_CONFIG must be 1 or 3." >&2
    exit 2
    ;;
esac

if ! command -v lscpu >/dev/null 2>&1; then
  echo "ERROR: lscpu is required for CPU and topology validation." >&2
  exit 1
fi

cpu_model=$(lscpu | awk -F: '/Model name/ {
  sub(/^[[:space:]]+/, "", $2); print $2; exit
}')
socket_count=$(lscpu -p=Socket 2>/dev/null |
  awk -F, '!/^#/ { seen[$1]=1 } END { print length(seen) }')
physical_cores=$(lscpu -p=Core,Socket 2>/dev/null |
  awk -F, '!/^#/ { seen[$1 "," $2]=1 } END { print length(seen) }')

if [ "$CPU_PROFILE" = auto ]; then
  case "$cpu_model" in
    *8592+*) CPU_PROFILE=8592plus ;;
    *8468*) CPU_PROFILE=8468 ;;
    *)
      echo "ERROR: supported CPU was not detected: $cpu_model" >&2
      echo "Use this helper only on dual-socket Xeon Platinum 8468 or 8592+." >&2
      exit 1
      ;;
  esac
fi

case "$CPU_PROFILE" in
  8468)
    expected_model=8468
    expected_cores=96
    default_configs="32x3 16x6 8x12 4x24"
    ;;
  8592plus)
    expected_model=8592+
    expected_cores=128
    default_configs="32x4 16x8 8x16 4x32"
    ;;
esac

case "$cpu_model" in
  *"$expected_model"*) ;;
  *)
    echo "ERROR: CPU_PROFILE=$CPU_PROFILE does not match detected CPU: $cpu_model" >&2
    exit 1
    ;;
esac
if [ "$socket_count" -ne 2 ] || [ "$physical_cores" -ne "$expected_cores" ]; then
  echo "ERROR: expected 2 sockets and $expected_cores physical cores." >&2
  echo "Detected sockets=$socket_count physical_cores=$physical_cores" >&2
  exit 1
fi

if [ -z "$CONFIGS" ]; then
  CONFIGS=$default_configs
fi

export TOOLCHAIN=intel
export ALLOW_NON_X86=0
export I_MPI_PIN=1
export I_MPI_PIN_DOMAIN=omp
export I_MPI_PIN_ORDER=compact
export KMP_AFFINITY=granularity=fine,compact,1,0

echo "FPSEID21_X86_GENERATION_SWEEP_PREFLIGHT_BEGIN"
echo "cpu_profile=$CPU_PROFILE"
echo "cpu_model=$cpu_model"
echo "sockets=$socket_count physical_cores=$physical_cores"
echo "configs=$CONFIGS"
echo "runs_per_config=$RUNS_PER_CONFIG"
echo "binding I_MPI_PIN=$I_MPI_PIN I_MPI_PIN_DOMAIN=$I_MPI_PIN_DOMAIN I_MPI_PIN_ORDER=$I_MPI_PIN_ORDER"
echo "KMP_AFFINITY=$KMP_AFFINITY"
echo "FPSEID21_X86_GENERATION_SWEEP_PREFLIGHT_END"

BUILD_ONLY=1 BUILD_MODE="$BUILD_MODE" RUNS=1 \
  "$SCRIPT_DIR/run_tddft_x86_baseline.sh"

CONFIGS="$CONFIGS" MAX_TOTAL_THREADS="$expected_cores" \
  RUNS_PER_CONFIG="$RUNS_PER_CONFIG" \
  "$SCRIPT_DIR/run_tddft_x86_mpi_omp_sweep.sh"
