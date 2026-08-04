#!/bin/sh
set -eu

# Build and measure only the accepted x86 configuration:
#   Intel oneAPI, 32 MPI ranks x 8 OpenMP threads, compact placement.
# CG and SD remain at one OpenMP thread; TDDFT uses eight threads per rank.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

RUNS=${RUNS:-3}
case "$RUNS" in
  1|3) ;;
  *)
    echo "ERROR: RUNS must be 1 or 3." >&2
    exit 2
    ;;
esac

TOOLCHAIN=intel
NPROCS=32
OMP_NUM_THREADS=8
ALLOW_NON_X86=0
I_MPI_PIN=1
I_MPI_PIN_DOMAIN=omp
I_MPI_PIN_ORDER=compact
KMP_AFFINITY=granularity=fine,compact,1,0

export RUNS TOOLCHAIN NPROCS OMP_NUM_THREADS ALLOW_NON_X86
export I_MPI_PIN I_MPI_PIN_DOMAIN I_MPI_PIN_ORDER KMP_AFFINITY

echo "FPSEID21 x86 fixed configuration: 32 MPI x 8 OpenMP"
echo "Runs: $RUNS"
echo "Binding: I_MPI_PIN=1 I_MPI_PIN_DOMAIN=omp I_MPI_PIN_ORDER=compact"
echo "KMP_AFFINITY=$KMP_AFFINITY"

exec "$SCRIPT_DIR/run_tddft_x86_baseline.sh"
