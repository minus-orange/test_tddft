#!/bin/sh
set -eu

# Read-only environment gate for the official diamond cb3x3x3 x86 runs.
# It does not build executables, create run files, or start a simulation.
#
# Usage:
#   EXPECTED_SKU=6980P ./tools/check_cb3x3x3_x86_environment.sh
#   EXPECTED_SKU=8468  ./tools/check_cb3x3x3_x86_environment.sh
#   EXPECTED_SKU=8592+ ./tools/check_cb3x3x3_x86_environment.sh
#
# Optional:
#   EXPECTED_REVISION=<full-or-abbreviated-commit>

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
EXPECTED_SKU=${EXPECTED_SKU:-}
EXPECTED_REVISION=${EXPECTED_REVISION:-}

failures=0
warnings=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

warn() {
  echo "WARN: $*" >&2
  warnings=$((warnings + 1))
}

first_line() {
  awk 'NF { print; exit }'
}

command_identity() {
  name=$1
  if command -v "$name" >/dev/null 2>&1; then
    path=$(command -v "$name")
    version=$("$name" --version 2>/dev/null | first_line || true)
    echo "${name}_path=$path"
    echo "${name}_version=$version"
  else
    echo "${name}_path=NOT_FOUND"
    fail "required command was not found: $name"
  fi
}

case "$(uname -s)" in
  Linux) ;;
  *) fail "Linux is required; detected $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "x86-64 is required; detected $(uname -m)" ;;
esac

for command_name in git awk sort; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "required command was not found: $command_name"
  fi
done

if command -v lscpu >/dev/null 2>&1; then
  cpu_model=$(lscpu | awk -F: '/Model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
  socket_count=$(lscpu -p=Socket 2>/dev/null |
    awk -F, '!/^#/ { seen[$1]=1 } END { print length(seen) }')
  physical_cores=$(lscpu -p=Core,Socket 2>/dev/null |
    awk -F, '!/^#/ { seen[$1 ":" $2]=1 } END { print length(seen) }')
  logical_cpus=$(lscpu -p=CPU 2>/dev/null |
    awk -F, '!/^#/ { count++ } END { print count+0 }')
  numa_nodes=$(lscpu -p=Node 2>/dev/null |
    awk -F, '!/^#/ && $1 >= 0 { seen[$1]=1 } END { print length(seen) }')
else
  fail "required command was not found: lscpu"
  cpu_model=UNKNOWN
  socket_count=0
  physical_cores=0
  logical_cpus=0
  numa_nodes=0
fi

case "$cpu_model" in
  *6980P*) detected_sku=6980P ;;
  *8468*) detected_sku=8468 ;;
  *8592+*) detected_sku=8592+ ;;
  *) detected_sku=UNKNOWN ;;
esac

case "$detected_sku" in
  6980P) formal_omp=8 ;;
  8468) formal_omp=3 ;;
  8592+) formal_omp=4 ;;
  *) formal_omp=UNKNOWN ;;
esac

if [ -n "$EXPECTED_SKU" ]; then
  case "$EXPECTED_SKU" in
    6980P|8468|8592+) ;;
    *) fail "EXPECTED_SKU must be 6980P, 8468, or 8592+" ;;
  esac
  if [ "$detected_sku" != "$EXPECTED_SKU" ]; then
    fail "CPU mismatch: expected $EXPECTED_SKU, detected $detected_sku ($cpu_model)"
  fi
fi

if [ "$socket_count" -ne 2 ]; then
  fail "two CPU sockets are required; detected $socket_count"
fi

if [ -r /proc/meminfo ]; then
  mem_total_kib=$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)
  mem_available_kib=$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)
else
  fail "/proc/meminfo is not readable"
  mem_total_kib=0
  mem_available_kib=0
fi
if [ -z "$mem_total_kib" ] || [ -z "$mem_available_kib" ]; then
  fail "MemTotal or MemAvailable is missing from /proc/meminfo"
  mem_total_kib=0
  mem_available_kib=0
fi
mem_total_gib=$(awk -v kib="$mem_total_kib" 'BEGIN { printf "%.2f", kib/1048576 }')
mem_available_gib=$(awk -v kib="$mem_available_kib" 'BEGIN { printf "%.2f", kib/1048576 }')

# Conservative MemAvailable gates for the current unmodified source. The
# known lower bounds include the fixed 480-band RHOOFK batch buffers, local
# COEF/COEF0, and EXTAU/EXTBF, but the gates add room for the other arrays,
# FFTW, MPI, OpenMP stacks, and the operating system.
recommended_nprocs=0
for candidate in 32 16 8 4 2 1; do
  case "$candidate" in
    32) required_gib=768 ;;
    16) required_gib=448 ;;
    8) required_gib=256 ;;
    4) required_gib=160 ;;
    2) required_gib=96 ;;
    1) required_gib=64 ;;
  esac
  if awk -v have="$mem_available_gib" -v need="$required_gib" \
    'BEGIN { exit !(have >= need) }'; then
    recommended_nprocs=$candidate
    recommended_required_gib=$required_gib
    break
  fi
done

if [ "$recommended_nprocs" -eq 0 ]; then
  recommended_omp=0
  recommended_required_gib=64
  fail "MemAvailable is below the 64 GiB gate for even one MPI rank"
else
  recommended_omp=$((physical_cores / recommended_nprocs))
  if [ $((physical_cores % recommended_nprocs)) -ne 0 ]; then
    warn "$physical_cores physical cores are not divisible by $recommended_nprocs ranks"
  fi
fi

if awk -v have="$mem_available_gib" 'BEGIN { exit !(have >= 768) }'; then
  formal_memory_gate=PASS
else
  formal_memory_gate=BLOCK
fi

cd "$ROOT_DIR"
branch=$(git branch --show-current 2>/dev/null || true)
revision=$(git rev-parse HEAD 2>/dev/null || true)
short_revision=$(git rev-parse --short=12 HEAD 2>/dev/null || true)
tracked_state=CLEAN
if ! git diff --quiet || ! git diff --cached --quiet; then
  tracked_state=DIRTY
  fail "tracked worktree or index is not clean"
fi
if [ "$branch" != tddft-openacc-residency ]; then
  fail "wrong branch: $branch"
fi
if [ -n "$EXPECTED_REVISION" ]; then
  case "$revision" in
    "$EXPECTED_REVISION"*) ;;
    *) fail "revision mismatch: expected $EXPECTED_REVISION, found $revision" ;;
  esac
fi
remote_sync=UNKNOWN
if git rev-parse --verify origin/tddft-openacc-residency >/dev/null 2>&1; then
  set -- $(git rev-list --left-right --count \
    origin/tddft-openacc-residency...HEAD)
  behind=$1
  ahead=$2
  remote_sync="behind_${behind}_ahead_${ahead}"
  if [ "$behind" -ne 0 ] || [ "$ahead" -ne 0 ]; then
    fail "branch is not synchronized with origin: behind=$behind ahead=$ahead"
  fi
else
  fail "origin/tddft-openacc-residency is not available"
fi

fftw_root=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-3.3.11-x86-intel/install"}
if [ -f "$fftw_root/include/fftw3.f" ] && \
   { [ -f "$fftw_root/lib/libfftw3.a" ] || \
     [ -f "$fftw_root/lib/libfftw3.so" ]; }; then
  fftw_state=READY
else
  fftw_state=NEEDS_BUILD
  warn "Intel FFTW installation is not ready under $fftw_root"
fi

echo "FPSEID21_CB3X3X3_X86_ENV_BEGIN"
echo "hostname=$(hostname)"
echo "kernel=$(uname -sr)"
echo "architecture=$(uname -m)"
echo "cpu_model=$cpu_model"
echo "detected_sku=$detected_sku"
echo "expected_sku=${EXPECTED_SKU:-NOT_SET}"
echo "sockets=$socket_count physical_cores=$physical_cores logical_cpus=$logical_cpus numa_nodes=$numa_nodes"
echo "mem_total_gib=$mem_total_gib"
echo "mem_available_gib=$mem_available_gib"
echo "formal_config=32mpi_x_${formal_omp}omp"
echo "formal_config_memory_gate=$formal_memory_gate"
echo "recommended_nprocs=$recommended_nprocs"
echo "recommended_omp_num_threads=$recommended_omp"
echo "recommended_memory_gate_gib=$recommended_required_gib"
echo "branch=$branch"
echo "revision=$revision"
echo "short_revision=$short_revision"
echo "tracked_state=$tracked_state"
echo "remote_sync=$remote_sync"
echo "fftw_root=$fftw_root"
echo "fftw_state=$fftw_state"
command_identity ifx
command_identity mpiifx
command_identity mpiicx
command_identity mpirun
echo "diagnostic=NOT_RUN"
echo "failures=$failures warnings=$warnings"
if [ "$failures" -eq 0 ]; then
  echo "environment_gate=PASS"
else
  echo "environment_gate=BLOCK"
fi
echo "FPSEID21_CB3X3X3_X86_ENV_END"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
