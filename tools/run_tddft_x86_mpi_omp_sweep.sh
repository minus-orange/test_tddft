#!/bin/sh
set -eu

# Screen x86 TDDFT MPI x OpenMP configurations without recompiling.
#
# Default grid:
#   MPI_COUNTS="4 8 16 32"
#   OMP_THREAD_COUNTS="2 4 8 16"
#   RUNS_PER_CONFIG=1
#
# CG and SD always run with one OpenMP thread so every TDDFT configuration
# starts from the same numerical preparation path. Only TDDFT uses the
# requested OpenMP thread count.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

MPI_COUNTS=${MPI_COUNTS:-"4 8 16 32"}
OMP_THREAD_COUNTS=${OMP_THREAD_COUNTS:-"2 4 8 16"}
RUNS_PER_CONFIG=${RUNS_PER_CONFIG:-1}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_x86"}
SWEEP_ROOT=${SWEEP_ROOT:-"$ROOT_DIR/run/x86_mpi_omp_sweeps"}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
MPIRUN=${MPIRUN:-mpirun}
CG_SD_FC=${CG_SD_FC:-ifx}
TDDFT_FC=${TDDFT_FC:-mpiifx}
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
I_MPI_PIN=${I_MPI_PIN:-1}
I_MPI_PIN_DOMAIN=${I_MPI_PIN_DOMAIN:-omp}
KMP_AFFINITY=${KMP_AFFINITY:-granularity=fine,compact,1,0}
X86_ENERGY_ATOL=${X86_ENERGY_ATOL:-1e-4}
X86_FORCE_ATOL=${X86_FORCE_ATOL:-2e-4}
X86_POSITION_ATOL=${X86_POSITION_ATOL:-2e-6}
X86_VELOCITY_ATOL=${X86_VELOCITY_ATOL:-1e-6}

CG_EXE=${CG_EXE:-"$ROOT_DIR/FPSEID21/cg_GGA_f_code/cg_exe"}
SD_EXE=${SD_EXE:-"$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe"}
TDDFT_EXE=${TDDFT_EXE:-"$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command was not found: $1" >&2
    exit 1
  }
}

require_executable() {
  if [ ! -x "$1" ]; then
    echo "ERROR: existing executable is required; no compilation is performed: $1" >&2
    exit 1
  fi
}

validate_positive_list() {
  list_name=$1
  list_value=$2
  count=0
  for value in $list_value; do
    case "$value" in
      ''|*[!0-9]*|0)
        echo "ERROR: $list_name must contain positive integers: $list_value" >&2
        exit 2
        ;;
    esac
    count=$((count + 1))
  done
  if [ "$count" -eq 0 ]; then
    echo "ERROR: $list_name must not be empty." >&2
    exit 2
  fi
}

normalize_wall() {
  awk '/steps took/ { value=$(NF-1) } END {
    if (value == "") exit 1
    gsub(/[dD]/, "E", value)
    printf "%.10f\n", value + 0
  }' "$1"
}

first_nonblank_line() {
  awk 'NF { print; exit }'
}

run_checked_compare() {
  output=$1
  err=$2
  python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
    "$output" --test-err "$err" --expected-steps 100 \
    --energy-atol "$X86_ENERGY_ATOL" \
    --force-atol "$X86_FORCE_ATOL" \
    --position-atol "$X86_POSITION_ATOL" \
    --velocity-atol "$X86_VELOCITY_ATOL"
}

case "$RUNS_PER_CONFIG" in
  1|3) ;;
  *)
    echo "ERROR: RUNS_PER_CONFIG must be 1 or 3." >&2
    exit 2
    ;;
esac
validate_positive_list MPI_COUNTS "$MPI_COUNTS"
validate_positive_list OMP_THREAD_COUNTS "$OMP_THREAD_COUNTS"

machine=$(uname -m)
case "$machine" in
  x86_64|amd64) ;;
  *)
    echo "ERROR: x86-64 is required; detected: $machine" >&2
    exit 1
    ;;
esac

require_command git
require_command python3
require_command "$MPIRUN"
require_command "$CG_SD_FC"
require_command "$TDDFT_FC"
require_command sort
require_executable "$CG_EXE"
require_executable "$SD_EXE"
require_executable "$TDDFT_EXE"

cd "$ROOT_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked worktree or index is not clean." >&2
  exit 1
fi

revision=$(git rev-parse HEAD)
short_revision=$(git rev-parse --short=12 HEAD)
cg_sd_compiler=$("$CG_SD_FC" --version 2>/dev/null | first_nonblank_line || true)
tddft_compiler=$("$TDDFT_FC" --version 2>/dev/null | first_nonblank_line || true)
mpi=$("$MPIRUN" --version 2>/dev/null | first_nonblank_line || true)
timestamp=$(date '+%Y%m%d_%H%M%S')
sweep_id=x86_mpi_omp_${timestamp}_${short_revision}
sweep_dir=$SWEEP_ROOT/$sweep_id
results_tsv=$sweep_dir/runs.tsv
summary_tsv=$sweep_dir/config_summary.tsv

logical_cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)
physical_cores=unknown
if command -v lscpu >/dev/null 2>&1; then
  physical_cores=$(lscpu -p=Core,Socket 2>/dev/null |
    awk -F, '!/^#/ { seen[$1 "," $2]=1 } END { print length(seen) }')
  cpu_model=$(lscpu | awk -F: '/Model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
else
  cpu_model=unknown
fi

mkdir -p "$sweep_dir" "$ARCHIVE_ROOT"
printf '%s\n' \
  "mpi_ranks	omp_threads	total_threads	run	wall_sec	normal	relaxed	run01_strict	oversubscribed	archive_label" \
  > "$results_tsv"
printf '%s\n' \
  "mpi_ranks	omp_threads	total_threads	median_sec	range_sec	oversubscribed" \
  > "$summary_tsv"

export OMP_STACKSIZE I_MPI_PIN I_MPI_PIN_DOMAIN KMP_AFFINITY

RUN_DIR="$RUN_DIR" TDDFT_STEPS=100 NPROCS=16 MPIRUN="$MPIRUN" \
  "$SCRIPT_DIR/prepare_si111_h_sample.sh"

echo
echo "Starting x86 MPI x OpenMP sweep"
echo "  revision=$revision"
echo "  cpu_model=$cpu_model"
echo "  cg_sd_compiler=$cg_sd_compiler"
echo "  tddft_compiler=$tddft_compiler"
echo "  mpi=$mpi"
echo "  logical_cpus=$logical_cpus physical_cores=$physical_cores"
echo "  mpi_counts=$MPI_COUNTS"
echo "  omp_thread_counts=$OMP_THREAD_COUNTS"
echo "  runs_per_config=$RUNS_PER_CONFIG"
echo "  I_MPI_PIN=$I_MPI_PIN I_MPI_PIN_DOMAIN=$I_MPI_PIN_DOMAIN"
echo "  KMP_AFFINITY=$KMP_AFFINITY"

for mpi_ranks in $MPI_COUNTS; do
  for omp_threads in $OMP_THREAD_COUNTS; do
    total_threads=$((mpi_ranks * omp_threads))
    oversubscribed=UNKNOWN
    case "$logical_cpus" in
      ''|*[!0-9]*) ;;
      *)
        if [ "$total_threads" -gt "$logical_cpus" ]; then
          oversubscribed=YES
        else
          oversubscribed=NO
        fi
        ;;
    esac

    config_walls=$sweep_dir/${mpi_ranks}mpi_${omp_threads}omp.walls
    : > "$config_walls"
    run01_archive=
    run_no=1
    while [ "$run_no" -le "$RUNS_PER_CONFIG" ]; do
      suffix=$(printf '%02d' "$run_no")
      label=${sweep_id}_${mpi_ranks}mpi_${omp_threads}omp_$suffix
      archive_dir=$ARCHIVE_ROOT/$label
      if [ -e "$archive_dir" ]; then
        echo "ERROR: archive already exists: $archive_dir" >&2
        exit 1
      fi

      echo
      echo "SWEEP_RUN mpi=$mpi_ranks omp=$omp_threads total=$total_threads run=$suffix oversubscribed=$oversubscribed"
      RUN_DIR="$RUN_DIR" TDDFT_INPUT=Si111-H_tm.in_100steps \
        NPROCS="$mpi_ranks" OMP_NUM_THREADS="$omp_threads" \
        CG_OMP_NUM_THREADS=1 SD_OMP_NUM_THREADS=1 \
        TDDFT_OMP_NUM_THREADS="$omp_threads" \
        OMP_STACKSIZE="$OMP_STACKSIZE" \
        CG_EXE="$CG_EXE" SD_EXE="$SD_EXE" TDDFT_EXE="$TDDFT_EXE" \
        MPIRUN="$MPIRUN" "$SCRIPT_DIR/run_si111_h_sample.sh"

      mkdir -p "$archive_dir"
      cp -p "$RUN_DIR/Si111-H_tm.in_100steps" "$archive_dir/tddft.in"
      cp -p "$RUN_DIR/Si111-H_tm.out" "$archive_dir/tddft.out"
      cp -p "$RUN_DIR/Si111-H_tm.err" "$archive_dir/tddft.err"

      if ! python3 "$SCRIPT_DIR/check_tddft_result.py" check \
        "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
        --expected-steps 100; then
        echo "ERROR: normal check failed for $label" >&2
        exit 1
      fi
      if ! run_checked_compare "$archive_dir/tddft.out" "$archive_dir/tddft.err"; then
        echo "ERROR: x86 relaxed compare failed for $label" >&2
        exit 1
      fi

      if [ "$run_no" -eq 1 ]; then
        run01_archive=$archive_dir
        strict=SELF
      else
        if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
          "$archive_dir/tddft.out" \
          --reference "$run01_archive/tddft.out" \
          --ref-err "$run01_archive/tddft.err" \
          --test-err "$archive_dir/tddft.err" \
          --strict --expected-steps 100; then
          echo "ERROR: run-01 strict compare failed for $label" >&2
          exit 1
        fi
        strict=PASS
      fi

      wall=$(normalize_wall "$archive_dir/tddft.out")
      printf '%s\n' "$wall" >> "$config_walls"
      printf '%s\t%s\t%s\t%s\t%s\tPASS\tPASS\t%s\t%s\t%s\n' \
        "$mpi_ranks" "$omp_threads" "$total_threads" "$suffix" "$wall" \
        "$strict" "$oversubscribed" "$label" >> "$results_tsv"

      {
        echo "revision=$revision"
        echo "cpu_model=$cpu_model"
        echo "cg_sd_compiler=$cg_sd_compiler"
        echo "tddft_compiler=$tddft_compiler"
        echo "mpi=$mpi"
        echo "logical_cpus=$logical_cpus"
        echo "physical_cores=$physical_cores"
        echo "mpi_ranks=$mpi_ranks"
        echo "omp_threads=$omp_threads"
        echo "total_threads=$total_threads"
        echo "oversubscribed=$oversubscribed"
        echo "omp_stacksize=$OMP_STACKSIZE"
        echo "i_mpi_pin=$I_MPI_PIN"
        echo "i_mpi_pin_domain=$I_MPI_PIN_DOMAIN"
        echo "kmp_affinity=$KMP_AFFINITY"
        echo "normal_check=PASS"
        echo "x86_relaxed_compare=PASS"
        echo "run01_pairwise_strict=$strict"
        echo "wall_sec=$wall"
      } > "$archive_dir/x86_sweep_provenance.env"

      run_no=$((run_no + 1))
    done

    config_sorted=$sweep_dir/${mpi_ranks}mpi_${omp_threads}omp.sorted
    sort -n "$config_walls" > "$config_sorted"
    if [ "$RUNS_PER_CONFIG" -eq 3 ]; then
      median=$(sed -n '2p' "$config_sorted")
    else
      median=$(sed -n '1p' "$config_sorted")
    fi
    range=$(awk 'NR == 1 { min=$1 } { max=$1 } END {
      printf "%.10f", max-min
    }' "$config_sorted")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$mpi_ranks" "$omp_threads" "$total_threads" "$median" "$range" \
      "$oversubscribed" >> "$summary_tsv"
  done
done

ranked_tsv=$sweep_dir/config_summary_ranked.tsv
{
  sed -n '1p' "$summary_tsv"
  sed -n '2,$p' "$summary_tsv" | sort -t '	' -k4,4n
} > "$ranked_tsv"

echo
echo "FPSEID21_X86_MPI_OMP_SWEEP_BEGIN"
echo "revision=$revision"
echo "cpu_model=$cpu_model"
echo "cg_sd_compiler=$cg_sd_compiler"
echo "tddft_compiler=$tddft_compiler"
echo "mpi=$mpi"
echo "logical_cpus=$logical_cpus physical_cores=$physical_cores"
echo "runs_per_config=$RUNS_PER_CONFIG"
echo "binding I_MPI_PIN=$I_MPI_PIN I_MPI_PIN_DOMAIN=$I_MPI_PIN_DOMAIN KMP_AFFINITY=$KMP_AFFINITY"
echo "tolerances energy=$X86_ENERGY_ATOL force=$X86_FORCE_ATOL position=$X86_POSITION_ATOL velocity=$X86_VELOCITY_ATOL"
echo "mpi omp total_threads median_sec range_sec oversubscribed"
sed -n '2,$p' "$ranked_tsv" | while IFS='	' read -r \
  mpi_ranks omp_threads total_threads median range oversubscribed
do
  echo "$mpi_ranks $omp_threads $total_threads $median $range $oversubscribed"
done
echo "results=$results_tsv"
echo "ranked_summary=$ranked_tsv"
echo "FPSEID21_X86_MPI_OMP_SWEEP_END"
