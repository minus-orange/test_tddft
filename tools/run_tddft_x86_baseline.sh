#!/bin/sh
set -eu

# Build and measure the CPU/FFTW TDDFT path on x86-64 Linux.
#
# Defaults:
#   TOOLCHAIN=gnu          GNU/OpenMPI (gfortran, mpifort, mpicc)
#   RUNS=3                 independent CG -> SD -> 100-step TDDFT runs
#   NPROCS=1               fixed performance-validation MPI rank count
#   OMP_NUM_THREADS=1      fixed performance-validation OpenMP thread count
#   RUN_DIR=<repo>/run/Si111-H_x86
#
# Intel oneAPI example:
#   TOOLCHAIN=intel ./tools/run_tddft_x86_baseline.sh
#
# Existing FFTW installation example:
#   SKIP_FFTW=1 FFTW_ROOT=/opt/fftw \
#     ./tools/run_tddft_x86_baseline.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

TOOLCHAIN=${TOOLCHAIN:-gnu}
RUNS=${RUNS:-3}
NPROCS=${NPROCS:-1}
OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_x86"}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
SKIP_FFTW=${SKIP_FFTW:-0}
ALLOW_NON_X86=${ALLOW_NON_X86:-0}

case "$RUNS" in
  1|3) ;;
  *)
    echo "ERROR: RUNS must be 1 or 3." >&2
    exit 2
    ;;
esac
if [ "$NPROCS" != 1 ]; then
  echo "ERROR: this baseline helper requires NPROCS=1." >&2
  exit 2
fi
if [ "$OMP_NUM_THREADS" != 1 ]; then
  echo "ERROR: this baseline helper requires OMP_NUM_THREADS=1." >&2
  exit 2
fi
case "$SKIP_FFTW" in
  0|1) ;;
  *)
    echo "ERROR: SKIP_FFTW must be 0 or 1." >&2
    exit 2
    ;;
esac

machine=$(uname -m)
case "$machine" in
  x86_64|amd64) ;;
  *)
    if [ "$ALLOW_NON_X86" != 1 ]; then
      echo "ERROR: x86-64 is required; detected: $machine" >&2
      echo "Set ALLOW_NON_X86=1 only for non-baseline portability checks." >&2
      exit 1
    fi
    ;;
esac

case "$TOOLCHAIN" in
  gnu)
    CG_FC=${CG_FC:-gfortran}
    SD_FC=${SD_FC:-gfortran}
    TDDFT_FC=${TDDFT_FC:-mpifort}
    TDDFT_CC=${TDDFT_CC:-mpicc}
    FFTW_CC=${FFTW_CC:-gcc}
    FFTW_FC=${FFTW_FC:-gfortran}
    FFTW_F77=${FFTW_F77:-gfortran}
    FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-3.3.11-x86-gnu/install"}
    ;;
  intel)
    CG_FC=${CG_FC:-ifx}
    SD_FC=${SD_FC:-ifx}
    TDDFT_FC=${TDDFT_FC:-mpiifx}
    TDDFT_CC=${TDDFT_CC:-mpiicx}
    FFTW_CC=${FFTW_CC:-icx}
    FFTW_FC=${FFTW_FC:-ifx}
    FFTW_F77=${FFTW_F77:-ifx}
    FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-3.3.11-x86-intel/install"}
    ;;
  *)
    echo "ERROR: TOOLCHAIN must be gnu or intel." >&2
    exit 2
    ;;
esac

MPIRUN=${MPIRUN:-mpirun}
export OMP_NUM_THREADS OMP_STACKSIZE

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command was not found: $1" >&2
    exit 1
  }
}

first_nonblank_line() {
  awk 'NF { print; exit }'
}

require_command git
require_command python3
require_command curl
require_command "$CG_FC"
require_command "$SD_FC"
require_command "$TDDFT_FC"
require_command "$TDDFT_CC"
require_command "$MPIRUN"
if [ "$SKIP_FFTW" = 0 ]; then
  require_command "$FFTW_CC"
  require_command "$FFTW_FC"
  require_command "$FFTW_F77"
fi

cd "$ROOT_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked worktree or index is not clean." >&2
  exit 1
fi

revision=$(git rev-parse HEAD)
short_revision=$(git rev-parse --short=12 HEAD)
timestamp=$(date '+%Y%m%d_%H%M%S')
label_prefix=${LABEL_PREFIX:-"x86_fftw_1rank_${TOOLCHAIN}_${timestamp}_${short_revision}"}

if [ "$SKIP_FFTW" = 0 ]; then
  PREFIX="$FFTW_ROOT" CC="$FFTW_CC" FC="$FFTW_FC" F77="$FFTW_F77" \
    "$SCRIPT_DIR/build_fftw3.sh"
elif [ ! -f "$FFTW_ROOT/include/fftw3.f" ]; then
  echo "ERROR: FFTW_ROOT does not contain include/fftw3.f: $FFTW_ROOT" >&2
  exit 1
fi

(
  cd "$ROOT_DIR/FPSEID21/cg_GGA_f_code"
  FC="$CG_FC" ./mk_ifort.sh
)
(
  cd "$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code"
  FC="$SD_FC" ./mk_ifort.sh
)
(
  cd "$ROOT_DIR/FPSEID21/tddft_2022October"
  FC="$TDDFT_FC" CC="$TDDFT_CC" FFT_BACKEND=fftw \
    FPSEID_FRPRMN_DIAGNOSTIC=0 FFTW_ROOT="$FFTW_ROOT" ./mk_ifort.sh
)

RUN_DIR="$RUN_DIR" TDDFT_STEPS=100 \
  "$SCRIPT_DIR/prepare_si111_h_sample.sh"

cpu_model=unknown
if command -v lscpu >/dev/null 2>&1; then
  cpu_model=$(lscpu | awk -F: '/Model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
elif [ -r /proc/cpuinfo ]; then
  cpu_model=$(awk -F: '/model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }' /proc/cpuinfo)
fi
compiler=$("$TDDFT_FC" --version 2>/dev/null | first_nonblank_line || true)
mpi=$("$MPIRUN" --version 2>/dev/null | first_nonblank_line || true)
kernel=$(uname -sr)

walls_file=$RUN_DIR/x86_wall_seconds.txt
: > "$walls_file"
run_no=1
run01_archive=
while [ "$run_no" -le "$RUNS" ]; do
  suffix=$(printf '%02d' "$run_no")
  label=${label_prefix}_$suffix
  archive_dir=$ARCHIVE_ROOT/$label
  if [ -e "$archive_dir" ]; then
    echo "ERROR: archive label already exists: $label" >&2
    exit 1
  fi

  RUN_DIR="$RUN_DIR" TDDFT_INPUT=Si111-H_tm.in_100steps \
    NPROCS=1 OMP_NUM_THREADS=1 OMP_STACKSIZE="$OMP_STACKSIZE" \
    CG_EXE="$ROOT_DIR/FPSEID21/cg_GGA_f_code/cg_exe" \
    SD_EXE="$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe" \
    TDDFT_EXE="$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" \
    MPIRUN="$MPIRUN" "$SCRIPT_DIR/run_si111_h_sample.sh"

  LABEL="$label" ARCHIVE_ROOT="$ARCHIVE_ROOT" \
    TDDFT_INPUT=Si111-H_tm.in_100steps \
    TDDFT_OUTPUT=Si111-H_tm.out TDDFT_ERR=Si111-H_tm.err \
    "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null

  python3 "$SCRIPT_DIR/check_tddft_result.py" check \
    "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null
  python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
    "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
    --expected-steps 100 >/dev/null

  if [ "$run_no" = 1 ]; then
    run01_archive=$archive_dir
    strict=SELF
  else
    python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$archive_dir/tddft.out" \
      --reference "$run01_archive/tddft.out" \
      --ref-err "$run01_archive/tddft.err" \
      --test-err "$archive_dir/tddft.err" \
      --strict --expected-steps 100 >/dev/null
    strict=PASS
  fi

  wall=$(awk '/steps took/ { value=$(NF-1) } END {
    if (value == "") exit 1
    print value
  }' "$archive_dir/tddft.out")
  printf '%s\n' "$wall" >> "$walls_file"

  {
    echo "revision=$revision"
    echo "architecture=$machine"
    echo "cpu_model=$cpu_model"
    echo "kernel=$kernel"
    echo "toolchain=$TOOLCHAIN"
    echo "compiler=$compiler"
    echo "mpi=$mpi"
    echo "fftw_root=$FFTW_ROOT"
    echo "nprocs=1"
    echo "omp_num_threads=1"
    echo "diagnostic=OFF"
    echo "normal_check=PASS"
    echo "relaxed_compare=PASS"
    echo "run01_pairwise_strict=$strict"
    echo "wall_sec=$wall"
  } > "$archive_dir/x86_provenance.env"

  run_no=$((run_no + 1))
done

sorted_walls=$RUN_DIR/x86_wall_seconds.sorted
sort -n "$walls_file" > "$sorted_walls"
if [ "$RUNS" = 3 ]; then
  median=$(sed -n '2p' "$sorted_walls")
else
  median=$(sed -n '1p' "$sorted_walls")
fi
range=$(awk 'NR == 1 { min=$1 } { max=$1 } END {
  printf "%.10f", max-min
}' "$sorted_walls")

echo
echo "FPSEID21_X86_BASELINE_BEGIN"
echo "revision=$revision"
echo "architecture=$machine"
echo "cpu_model=$cpu_model"
echo "kernel=$kernel"
echo "toolchain=$TOOLCHAIN"
echo "compiler=$compiler"
echo "mpi=$mpi"
echo "fftw_root=$FFTW_ROOT"
echo "runs=$RUNS nprocs=1 omp_num_threads=1 diagnostic=OFF"
run_no=1
while IFS= read -r wall; do
  suffix=$(printf '%02d' "$run_no")
  echo "run_$suffix label=${label_prefix}_$suffix wall_sec=$wall check=PASS compare=PASS"
  run_no=$((run_no + 1))
done < "$walls_file"
echo "median_sec=$median"
echo "range_sec=$range"
echo "archives=$ARCHIVE_ROOT/${label_prefix}_<01..$(printf '%02d' "$RUNS")>"
echo "FPSEID21_X86_BASELINE_END"
