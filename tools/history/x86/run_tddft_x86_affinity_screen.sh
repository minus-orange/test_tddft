#!/bin/sh
set -eu

# Compare Intel MPI rank-domain ordering at the accepted x86 configuration.
# Existing ifx/mpiifx CPU/FFTW executables are required and never rebuilt.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOLS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ROOT_DIR=$(CDPATH= cd -- "$TOOLS_DIR/.." && pwd)

PIN_ORDERS=${PIN_ORDERS:-"compact scatter spread"}
NPROCS=${NPROCS:-32}
OMP_NUM_THREADS=${OMP_NUM_THREADS:-8}
MAX_TOTAL_THREADS=${MAX_TOTAL_THREADS:-256}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_x86"}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
SCREEN_ROOT=${SCREEN_ROOT:-"$ROOT_DIR/run/x86_affinity_screens"}
MPIRUN=${MPIRUN:-mpirun}
I_MPI_PIN_DOMAIN=${I_MPI_PIN_DOMAIN:-omp}
KMP_AFFINITY=${KMP_AFFINITY:-granularity=fine,compact,1,0}

validate_positive() {
  name=$1
  value=$2
  case "$value" in
    ''|*[!0-9]*|0)
      echo "ERROR: $name must be a positive integer: $value" >&2
      exit 2
      ;;
  esac
}

first_order=
order_count=0
for order in $PIN_ORDERS; do
  case "$order" in
    compact|scatter|spread) ;;
    *)
      echo "ERROR: PIN_ORDERS supports compact, scatter, and spread only: $order" >&2
      exit 2
      ;;
  esac
  if [ -z "$first_order" ]; then
    first_order=$order
  fi
  order_count=$((order_count + 1))
done
if [ "$order_count" -lt 2 ]; then
  echo "ERROR: PIN_ORDERS must contain at least two orders." >&2
  exit 2
fi
if [ "$first_order" != compact ]; then
  echo "ERROR: compact must be the first PIN_ORDERS control." >&2
  exit 2
fi

validate_positive NPROCS "$NPROCS"
validate_positive OMP_NUM_THREADS "$OMP_NUM_THREADS"
validate_positive MAX_TOTAL_THREADS "$MAX_TOTAL_THREADS"
total_threads=$((NPROCS * OMP_NUM_THREADS))
if [ "$total_threads" -gt "$MAX_TOTAL_THREADS" ]; then
  echo "ERROR: requested total threads exceed MAX_TOTAL_THREADS: $total_threads > $MAX_TOTAL_THREADS" >&2
  exit 2
fi

machine=$(uname -m)
case "$machine" in
  x86_64|amd64) ;;
  *)
    echo "ERROR: x86-64 is required; detected: $machine" >&2
    exit 1
    ;;
esac

cd "$ROOT_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked worktree or index is not clean." >&2
  exit 1
fi

revision=$(git rev-parse HEAD)
short_revision=$(git rev-parse --short=12 HEAD)
kernel=$(uname -srmo)
numa_nodes=unknown
if command -v lscpu >/dev/null 2>&1; then
  numa_nodes=$(lscpu | awk -F: '/NUMA node\(s\)/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
fi
timestamp=$(date '+%Y%m%d_%H%M%S')
screen_id=x86_affinity_${timestamp}_${short_revision}
screen_dir=$SCREEN_ROOT/$screen_id
child_root=$screen_dir/sweeps
screen_tsv=$screen_dir/affinity_results.tsv
ranked_tsv=$screen_dir/affinity_results_ranked.tsv
mkdir -p "$screen_dir" "$child_root"

printf '%s\n' \
  "pin_order	wall_sec	normal	relaxed	control_strict	archive_label	child_results" \
  > "$screen_tsv"

control_archive=
cpu_model=
cg_sd_compiler=
tddft_compiler=
mpi=
cpu_topology=
for order in $PIN_ORDERS; do
  log=$screen_dir/$order.log
  echo "AFFINITY_RUN pin_order=$order mpi=$NPROCS omp=$OMP_NUM_THREADS total=$total_threads"

  if ! I_MPI_PIN_DOMAIN="$I_MPI_PIN_DOMAIN" I_MPI_PIN_ORDER="$order" \
    KMP_AFFINITY="$KMP_AFFINITY" \
    MPI_COUNTS="$NPROCS" OMP_THREAD_COUNTS="$OMP_NUM_THREADS" \
    MAX_TOTAL_THREADS="$MAX_TOTAL_THREADS" RUNS_PER_CONFIG=1 \
    RUN_DIR="$RUN_DIR" ARCHIVE_ROOT="$ARCHIVE_ROOT" \
    SWEEP_ROOT="$child_root" MPIRUN="$MPIRUN" \
    "$TOOLS_DIR/run_tddft_x86_mpi_omp_sweep.sh" > "$log" 2>&1; then
    echo "ERROR: affinity run failed: $order" >&2
    tail -n 80 "$log" >&2
    exit 1
  fi

  results=$(awk -F= '/^results=/ { value=$2 } END { print value }' "$log")
  if [ ! -f "$results" ]; then
    echo "ERROR: child results were not found for $order: $results" >&2
    exit 1
  fi
  wall=$(awk -F '	' 'NR == 2 { print $5 }' "$results")
  archive_label=$(awk -F '	' 'NR == 2 { print $10 }' "$results")
  archive_dir=$ARCHIVE_ROOT/$archive_label
  if [ -z "$wall" ] || [ -z "$archive_label" ] ||
    [ ! -f "$archive_dir/tddft.out" ] ||
    [ ! -f "$archive_dir/tddft.err" ]; then
    echo "ERROR: incomplete child result for $order" >&2
    exit 1
  fi

  if [ "$order" = compact ]; then
    control_archive=$archive_dir
    control_strict=SELF
    cpu_model=$(awk -F= '/^cpu_model=/ { value=$2 } END { print value }' "$log")
    cg_sd_compiler=$(awk -F= '/^cg_sd_compiler=/ { value=$2 } END { print value }' "$log")
    tddft_compiler=$(awk -F= '/^tddft_compiler=/ { value=$2 } END { print value }' "$log")
    mpi=$(awk -F= '/^mpi=/ { value=$2 } END { print value }' "$log")
    cpu_topology=$(awk -F= '/^logical_cpus=/ { value=substr($0, index($0, "=")+1) } END { print value }' "$log")
  else
    if ! python3 "$TOOLS_DIR/check_tddft_result.py" compare \
      "$archive_dir/tddft.out" \
      --reference "$control_archive/tddft.out" \
      --ref-err "$control_archive/tddft.err" \
      --test-err "$archive_dir/tddft.err" \
      --strict --expected-steps 100 > "$screen_dir/$order.control_strict.log"; then
      cat "$screen_dir/$order.control_strict.log" >&2
      echo "ERROR: strict comparison with compact control failed: $order" >&2
      exit 1
    fi
    control_strict=PASS
  fi

  printf '%s\t%s\tPASS\tPASS\t%s\t%s\t%s\n' \
    "$order" "$wall" "$control_strict" "$archive_label" "$results" \
    >> "$screen_tsv"
done

{
  sed -n '1p' "$screen_tsv"
  sed -n '2,$p' "$screen_tsv" | sort -t '	' -k2,2n
} > "$ranked_tsv"
best_order=$(awk -F '	' 'NR == 2 { print $1 }' "$ranked_tsv")
best_wall=$(awk -F '	' 'NR == 2 { print $2 }' "$ranked_tsv")
control_wall=$(awk -F '	' '$1 == "compact" { print $2 }' "$screen_tsv")
improvement=$(awk -v control="$control_wall" -v best="$best_wall" \
  'BEGIN { printf "%.10f", control-best }')
improvement_pct=$(awk -v control="$control_wall" -v best="$best_wall" \
  'BEGIN { printf "%.6f", (control-best)/control*100 }')

echo
echo "FPSEID21_X86_AFFINITY_SCREEN_BEGIN"
echo "revision=$revision"
echo "cpu_model=$cpu_model"
echo "kernel=$kernel"
echo "cg_sd_compiler=$cg_sd_compiler"
echo "tddft_compiler=$tddft_compiler"
echo "mpi=$mpi"
echo "cpu_topology=$cpu_topology"
echo "numa_nodes=$numa_nodes"
echo "mpi_ranks=$NPROCS omp_threads=$OMP_NUM_THREADS total_threads=$total_threads"
echo "pin_domain=$I_MPI_PIN_DOMAIN kmp_affinity=$KMP_AFFINITY"
echo "pin_order wall_sec normal relaxed compact_pairwise_strict"
awk -F '	' 'NR > 1 {
  print $1, $2, $3, $4, $5
}' "$ranked_tsv"
echo "best_order=$best_order best_wall_sec=$best_wall"
echo "compact_wall_sec=$control_wall improvement_sec=$improvement improvement_pct=$improvement_pct"
echo "results=$screen_tsv"
echo "ranked_summary=$ranked_tsv"
echo "FPSEID21_X86_AFFINITY_SCREEN_END"
