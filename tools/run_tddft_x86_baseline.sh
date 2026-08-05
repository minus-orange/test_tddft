#!/bin/sh
set -eu

# Build and measure the CPU/FFTW TDDFT path on x86-64 Linux.
#
# Defaults:
#   TOOLCHAIN=intel        Intel oneAPI (ifx, mpiifx, mpiicx)
#   RUNS=3                 independent CG -> SD -> 100-step TDDFT runs
#   NPROCS=16              default x86 performance MPI rank count
#   OMP_NUM_THREADS=1      TDDFT OpenMP thread count (CG/SD remain at 1)
#   BUILD_MODE=auto        reuse a matching existing build
#   X86_FORCE_ATOL=2e-4    cross-toolchain tolerance in Hartree/Bohr
#   X86_POSITION_ATOL=2e-6 cross-toolchain tolerance in Bohr
#   RUN_DIR=<repo>/run/Si111-H_x86
#
# Force a rebuild:
#   BUILD_MODE=always ./tools/run_tddft_x86_baseline.sh
#
# Require an existing build without compiling:
#   BUILD_MODE=never ./tools/run_tddft_x86_baseline.sh
#
# GNU/OpenMPI override:
#   TOOLCHAIN=gnu ./tools/run_tddft_x86_baseline.sh
#
# Existing FFTW installation example:
#   SKIP_FFTW=1 FFTW_ROOT=/opt/fftw \
#     ./tools/run_tddft_x86_baseline.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

TOOLCHAIN=${TOOLCHAIN:-intel}
RUNS=${RUNS:-3}
NPROCS=${NPROCS:-16}
OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
I_MPI_PIN=${I_MPI_PIN:-1}
I_MPI_PIN_DOMAIN=${I_MPI_PIN_DOMAIN:-omp}
I_MPI_PIN_ORDER=${I_MPI_PIN_ORDER:-compact}
KMP_AFFINITY=${KMP_AFFINITY:-granularity=fine,compact,1,0}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_x86"}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
SKIP_FFTW=${SKIP_FFTW:-0}
ALLOW_NON_X86=${ALLOW_NON_X86:-0}
BUILD_MODE=${BUILD_MODE:-auto}
BUILD_ONLY=${BUILD_ONLY:-0}
BUILD_CACHE_DIR=${BUILD_CACHE_DIR:-"$ROOT_DIR/.cache/tddft_x86_build"}
X86_ENERGY_ATOL=${X86_ENERGY_ATOL:-1e-4}
X86_FORCE_ATOL=${X86_FORCE_ATOL:-2e-4}
X86_POSITION_ATOL=${X86_POSITION_ATOL:-2e-6}
X86_VELOCITY_ATOL=${X86_VELOCITY_ATOL:-1e-6}

case "$RUNS" in
  1|3) ;;
  *)
    echo "ERROR: RUNS must be 1 or 3." >&2
    exit 2
    ;;
esac
case "$NPROCS" in
  ''|*[!0-9]*|0)
    echo "ERROR: NPROCS must be a positive integer." >&2
    exit 2
    ;;
esac
case "$OMP_NUM_THREADS" in
  ''|*[!0-9]*|0)
    echo "ERROR: OMP_NUM_THREADS must be a positive integer." >&2
    exit 2
    ;;
esac
case "$I_MPI_PIN_ORDER" in
  compact|scatter|spread|bunch|range) ;;
  *)
    echo "ERROR: unsupported I_MPI_PIN_ORDER: $I_MPI_PIN_ORDER" >&2
    exit 2
    ;;
esac
case "$SKIP_FFTW" in
  0|1) ;;
  *)
    echo "ERROR: SKIP_FFTW must be 0 or 1." >&2
    exit 2
    ;;
esac
case "$BUILD_MODE" in
  auto|always|never) ;;
  *)
    echo "ERROR: BUILD_MODE must be auto, always, or never." >&2
    exit 2
    ;;
esac
case "$BUILD_ONLY" in
  0|1) ;;
  *)
    echo "ERROR: BUILD_ONLY must be 0 or 1." >&2
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
export I_MPI_PIN I_MPI_PIN_DOMAIN I_MPI_PIN_ORDER KMP_AFFINITY

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command was not found: $1" >&2
    exit 1
  }
}

first_nonblank_line() {
  awk 'NF { print; exit }'
}

compiler_identity() {
  compiler_name=$1
  compiler_path=$(command -v "$compiler_name")
  compiler_version=$("$compiler_name" --version 2>/dev/null |
    first_nonblank_line || true)
  printf '%s=%s|%s\n' "$compiler_name" "$compiler_path" "$compiler_version"
}

fftw_is_ready() {
  [ -f "$FFTW_ROOT/include/fftw3.f" ]
}

executables_are_ready() {
  [ -x "$CG_EXE" ] &&
    [ -x "$SD_EXE" ] &&
    [ -x "$TDDFT_EXE" ]
}

component_can_be_reused() {
  component_signature=$1
  component_stamp=$2
  component_executable=$3

  case "$BUILD_MODE" in
    always)
      return 1
      ;;
    never)
      [ -x "$component_executable" ]
      return
      ;;
    auto)
      if [ ! -x "$component_executable" ]; then
        return 1
      fi
      if [ -f "$component_stamp" ] &&
        [ "$(sed -n '1p' "$component_stamp")" = "$component_signature" ]; then
        return 0
      fi
      return 1
      ;;
  esac
}

record_component_signature() {
  component_signature=$1
  component_stamp=$2
  mkdir -p "$BUILD_CACHE_DIR"
  printf '%s\n' "$component_signature" > "$component_stamp"
}

require_command git
require_command python3
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
label_prefix=${LABEL_PREFIX:-"x86_fftw_${NPROCS}mpi_${OMP_NUM_THREADS}omp_${TOOLCHAIN}_${timestamp}_${short_revision}"}

CG_EXE="$ROOT_DIR/FPSEID21/cg_GGA_f_code/cg_exe"
SD_EXE="$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe"
TDDFT_EXE="$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"
CG_BUILD_STAMP="$BUILD_CACHE_DIR/$TOOLCHAIN.cg.stamp"
SD_BUILD_STAMP="$BUILD_CACHE_DIR/$TOOLCHAIN.sd.stamp"
TDDFT_BUILD_STAMP="$BUILD_CACHE_DIR/$TOOLCHAIN.tddft.stamp"

cg_build_signature=$(
  {
    git ls-files -s -- FPSEID21/cg_GGA_f_code
    printf '%s\n' \
      "toolchain=$TOOLCHAIN" \
      "cg_fc=$CG_FC"
    compiler_identity "$CG_FC"
  } | git hash-object --stdin
)
sd_build_signature=$(
  {
    git ls-files -s -- FPSEID21/sd_GGA_f_compact_code
    printf '%s\n' \
      "toolchain=$TOOLCHAIN" \
      "sd_fc=$SD_FC"
    compiler_identity "$SD_FC"
  } | git hash-object --stdin
)
tddft_build_signature=$(
  {
    git ls-files -s -- \
      FPSEID21/tddft_2022October \
      tools/build_fftw3.sh
    printf '%s\n' \
      "toolchain=$TOOLCHAIN" \
      "tddft_fc=$TDDFT_FC" \
      "tddft_cc=$TDDFT_CC" \
      "fftw_cc=$FFTW_CC" \
      "fftw_fc=$FFTW_FC" \
      "fftw_f77=$FFTW_F77" \
      "fftw_root=$FFTW_ROOT" \
      "fft_backend=fftw" \
      "diagnostic=0"
    compiler_identity "$TDDFT_FC"
    compiler_identity "$TDDFT_CC"
    compiler_identity "$FFTW_CC"
    compiler_identity "$FFTW_FC"
    compiler_identity "$FFTW_F77"
  } | git hash-object --stdin
)

if [ "$BUILD_MODE" = never ]; then
  if ! fftw_is_ready; then
    echo "ERROR: BUILD_MODE=never but FFTW is missing: $FFTW_ROOT" >&2
    exit 1
  fi
  if ! executables_are_ready; then
    echo "ERROR: BUILD_MODE=never but one or more executables are missing." >&2
    exit 1
  fi
fi

fftw_reused=1
if [ "$SKIP_FFTW" = 0 ]; then
  if [ "$BUILD_MODE" = always ] || ! fftw_is_ready; then
    fftw_reused=0
    require_command curl
    PREFIX="$FFTW_ROOT" CC="$FFTW_CC" FC="$FFTW_FC" F77="$FFTW_F77" \
      "$SCRIPT_DIR/build_fftw3.sh"
  else
    echo "Reusing existing FFTW installation: $FFTW_ROOT"
  fi
elif ! fftw_is_ready; then
  echo "ERROR: FFTW_ROOT does not contain include/fftw3.f: $FFTW_ROOT" >&2
  exit 1
fi

cg_reused=0
if component_can_be_reused \
  "$cg_build_signature" "$CG_BUILD_STAMP" "$CG_EXE"; then
  cg_reused=1
  echo "Reusing CG executable: $CG_EXE"
else
  (
    cd "$ROOT_DIR/FPSEID21/cg_GGA_f_code"
    FC="$CG_FC" ./mk_ifort.sh
  )
fi
record_component_signature "$cg_build_signature" "$CG_BUILD_STAMP"

sd_reused=0
if component_can_be_reused \
  "$sd_build_signature" "$SD_BUILD_STAMP" "$SD_EXE"; then
  sd_reused=1
  echo "Reusing SD executable: $SD_EXE"
else
  (
    cd "$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code"
    FC="$SD_FC" ./mk_ifort.sh
  )
fi
record_component_signature "$sd_build_signature" "$SD_BUILD_STAMP"

tddft_reused=0
if [ "$fftw_reused" = 1 ] &&
  component_can_be_reused \
  "$tddft_build_signature" "$TDDFT_BUILD_STAMP" "$TDDFT_EXE"; then
  tddft_reused=1
  echo "Reusing TDDFT executable: $TDDFT_EXE"
else
  (
    cd "$ROOT_DIR/FPSEID21/tddft_2022October"
    FC="$TDDFT_FC" CC="$TDDFT_CC" FFT_BACKEND=fftw \
      FPSEID_FRPRMN_DIAGNOSTIC=0 FFTW_ROOT="$FFTW_ROOT" ./mk_ifort.sh
  )
fi
record_component_signature "$tddft_build_signature" "$TDDFT_BUILD_STAMP"

if [ "$fftw_reused" = 1 ] &&
  [ "$cg_reused" = 1 ] &&
  [ "$sd_reused" = 1 ] &&
  [ "$tddft_reused" = 1 ]; then
  reuse_build=1
else
  reuse_build=0
fi

if [ "$BUILD_ONLY" = 1 ]; then
  echo
  echo "FPSEID21_X86_BUILD_ONLY_BEGIN"
  echo "revision=$revision"
  echo "toolchain=$TOOLCHAIN"
  echo "fftw_root=$FFTW_ROOT"
  echo "build_mode=$BUILD_MODE"
  echo "build_reused=$reuse_build"
  echo "fftw_reused=$fftw_reused cg_reused=$cg_reused sd_reused=$sd_reused tddft_reused=$tddft_reused"
  echo "diagnostic=OFF"
  echo "FPSEID21_X86_BUILD_ONLY_END"
  exit 0
fi

RUN_DIR="$RUN_DIR" TDDFT_STEPS=100 NPROCS="$NPROCS" MPIRUN="$MPIRUN" \
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
    NPROCS="$NPROCS" OMP_NUM_THREADS="$OMP_NUM_THREADS" \
    CG_OMP_NUM_THREADS=1 SD_OMP_NUM_THREADS=1 \
    TDDFT_OMP_NUM_THREADS="$OMP_NUM_THREADS" OMP_STACKSIZE="$OMP_STACKSIZE" \
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
    --expected-steps 100 \
    --energy-atol "$X86_ENERGY_ATOL" \
    --force-atol "$X86_FORCE_ATOL" \
    --position-atol "$X86_POSITION_ATOL" \
    --velocity-atol "$X86_VELOCITY_ATOL" >/dev/null

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
    gsub(/[dD]/, "E", value)
    printf "%.10f\n", value + 0
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
    echo "build_mode=$BUILD_MODE"
    echo "build_reused=$reuse_build"
    echo "fftw_reused=$fftw_reused"
    echo "cg_reused=$cg_reused"
    echo "sd_reused=$sd_reused"
    echo "tddft_reused=$tddft_reused"
    echo "nprocs=$NPROCS"
    echo "omp_num_threads=$OMP_NUM_THREADS"
    echo "cg_omp_num_threads=1"
    echo "sd_omp_num_threads=1"
    echo "i_mpi_pin=$I_MPI_PIN"
    echo "i_mpi_pin_domain=$I_MPI_PIN_DOMAIN"
    echo "i_mpi_pin_order=$I_MPI_PIN_ORDER"
    echo "kmp_affinity=$KMP_AFFINITY"
    echo "diagnostic=OFF"
    echo "energy_atol=$X86_ENERGY_ATOL"
    echo "force_atol=$X86_FORCE_ATOL"
    echo "position_atol=$X86_POSITION_ATOL"
    echo "velocity_atol=$X86_VELOCITY_ATOL"
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
echo "build_mode=$BUILD_MODE"
echo "build_reused=$reuse_build"
echo "fftw_reused=$fftw_reused cg_reused=$cg_reused sd_reused=$sd_reused tddft_reused=$tddft_reused"
echo "runs=$RUNS nprocs=$NPROCS omp_num_threads=$OMP_NUM_THREADS diagnostic=OFF"
echo "binding i_mpi_pin=$I_MPI_PIN i_mpi_pin_domain=$I_MPI_PIN_DOMAIN i_mpi_pin_order=$I_MPI_PIN_ORDER"
echo "kmp_affinity=$KMP_AFFINITY"
echo "tolerances energy=$X86_ENERGY_ATOL force=$X86_FORCE_ATOL position=$X86_POSITION_ATOL velocity=$X86_VELOCITY_ATOL"
run_no=1
while IFS= read -r wall; do
  suffix=$(printf '%02d' "$run_no")
  if [ "$run_no" = 1 ]; then
    strict_summary=SELF
  else
    strict_summary=PASS
  fi
  echo "run_$suffix label=${label_prefix}_$suffix wall_sec=$wall check=PASS compare=PASS strict=$strict_summary"
  run_no=$((run_no + 1))
done < "$walls_file"
echo "median_sec=$median"
echo "range_sec=$range"
echo "archives=$ARCHIVE_ROOT/${label_prefix}_<01..$(printf '%02d' "$RUNS")>"
echo "FPSEID21_X86_BASELINE_END"
