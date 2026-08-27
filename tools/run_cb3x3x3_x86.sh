#!/bin/sh
set -eu

# Build and run the official 2026-08-08 diamond cb3x3x3 benchmark on one
# validated Intel x86 host. Numerical source files are never edited.
#
# The stages are intentionally separate so CG, SD, and TDDFT results can be
# reviewed before the next expensive calculation starts:
#
#   EXPECTED_SKU=6980P ./tools/run_cb3x3x3_x86.sh build
#   EXPECTED_SKU=6980P ./tools/run_cb3x3x3_x86.sh cg
#   EXPECTED_SKU=6980P ./tools/run_cb3x3x3_x86.sh sd
#   EXPECTED_SKU=6980P ./tools/run_cb3x3x3_x86.sh tddft-2
#
# A user-authorized 100-step diagnostic requires explicit confirmation and a
# unique label, but no reference comparison or baseline adoption is allowed:
#
#   EXPECTED_SKU=8592+ CONFIRM_LONG_RUN=YES LABEL=<label> \
#     ./tools/run_cb3x3x3_x86.sh tddft-100
#
# Reference-backed long runs also require confirmation and a unique label:
#
#   EXPECTED_SKU=8468 CONFIRM_LONG_RUN=YES LABEL=<label> \
#     ./tools/run_cb3x3x3_x86.sh tddft-40000
#
# A 1000-step run also requires an approved same-input reference:
#
#   EXPECTED_SKU=8592+ CONFIRM_LONG_RUN=YES LABEL=<label> \
#   REFERENCE_OUTPUT=<approved-1000-step-output> \
#     ./tools/run_cb3x3x3_x86.sh tddft-1000

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

ACTION=${1:-}
EXPECTED_SKU=${EXPECTED_SKU:-}
EXPECTED_REVISION=${EXPECTED_REVISION:-}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
WORK_ROOT=$BENCHMARK_ROOT/work
CG_DIR=$WORK_ROOT/cg
SD_DIR=$WORK_ROOT/sd
STATE_DIR=$WORK_ROOT/tddft_600K
FFTW_ROOT=${FFTW_ROOT:-"$ROOT_DIR/tools/fftw-3.3.11-x86-intel/install"}
BUILD_MODE=${BUILD_MODE:-auto}
CG_SD_OMP_NUM_THREADS=${CG_SD_OMP_NUM_THREADS:-1}
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
MPIRUN=${MPIRUN:-mpirun}
CONFIRM_LONG_RUN=${CONFIRM_LONG_RUN:-NO}

usage() {
  cat <<'EOF'
Usage: EXPECTED_SKU=<6980P|8468|8592+> ./tools/run_cb3x3x3_x86.sh ACTION

Actions:
  build          Build/reuse Intel CG, SD, and CPU/FFTW TDDFT executables.
  cg             Build, run CG, validate it, and preserve its state.
  sd             Build, run SD from the validated CG state, validate it, and
                 install a write-protected canonical TDDFT initial state.
  tddft-2        Run a bounded two-step startup/memory check. No baseline.
  tddft-100      Run a user-authorized 100-step diagnostic. Requires
                 CONFIRM_LONG_RUN=YES and LABEL. Normal check only; no
                 same-input comparison and no baseline.
  tddft-1000     Run 1000 steps. Requires CONFIRM_LONG_RUN=YES, LABEL, and an
                 approved same-input REFERENCE_OUTPUT.
  tddft-40000    Run the official 40000-step case. Requires
                 CONFIRM_LONG_RUN=YES and LABEL.

The fixed TDDFT configurations are 6980P=16 MPI x 16 OpenMP,
8468=32 MPI x 3 OpenMP, and 8592+=32 MPI x 4 OpenMP.
CG and SD default to one OpenMP thread for deterministic state generation.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "required file is missing: $1"
}

require_nonempty() {
  [ -s "$1" ] || fail "required file is missing or empty: $1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command was not found: $1"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

copy_new() {
  src=$1
  dst=$2
  label=$3
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    fail "$label already exists; refusing to overwrite: $dst"
  fi
  part=$dst.part.$$
  [ ! -e "$part" ] || fail "stale partial file exists: $part"
  cp -p "$src" "$part"
  mv "$part" "$dst"
}

link_new() {
  target=$1
  link=$2
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    return 0
  fi
  if [ -e "$link" ] || [ -L "$link" ]; then
    fail "path blocks required link: $link"
  fi
  ln -s "$target" "$link"
}

check_log() {
  stage=$1
  out=$2
  err=$3

  require_nonempty "$out"
  if [ -s "$err" ] &&
     grep -Eiq '(^|[^A-Z])(error|fatal|segmentation|sigsegv|traceback|cannot|failed|invalid|badfmt)' "$err"; then
    fail "$stage stderr contains an error marker: $err"
  fi
  grep -q 'CPU TIME END OF PSPW' "$out" ||
    fail "$stage completion marker is missing: CPU TIME END OF PSPW"
  grep -q 'TOTAL ENERGY: ETOT' "$out" ||
    fail "$stage total-energy line is missing"
  if grep -Eiq 'NaN|Infinity|SIGSEGV|segmentation|fatal|traceback|cannot|failed|invalid|BADFMT|FIO-F-[0-9]+' "$out"; then
    fail "$stage stdout contains a suspicious marker: $out"
  fi

  force_count=$(awk '
    /TOTAL FORCE:/ {in_force=1; next}
    in_force && NF == 4 && $1 ~ /^[0-9]+$/ {count++; next}
    in_force && count > 0 && NF != 4 {exit}
    END {print count + 0}
  ' "$out")
  [ "$force_count" -eq 216 ] ||
    fail "$stage force block has $force_count atoms; expected 216"

  etot=$(awk '/TOTAL ENERGY: ETOT/ {value=$(NF-1)} END {print value}' "$out")
  echo "${stage}_check=PASS"
  echo "${stage}_force_atoms=$force_count"
  echo "${stage}_final_etot_hr=$etot"
}

first_nonblank_line() {
  awk 'NF {print; exit}'
}

detect_sku() {
  cpu_model=$(lscpu | awk -F: '/Model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
  case "$cpu_model" in
    *6980P*) detected_sku=6980P ;;
    *8468*) detected_sku=8468 ;;
    *8592+*) detected_sku=8592+ ;;
    *) fail "unsupported CPU model: $cpu_model" ;;
  esac
}

set_fixed_configuration() {
  case "$detected_sku" in
    6980P) NPROCS=16; TDDFT_OMP_NUM_THREADS=16 ;;
    8468) NPROCS=32; TDDFT_OMP_NUM_THREADS=3 ;;
    8592+) NPROCS=32; TDDFT_OMP_NUM_THREADS=4 ;;
  esac
}

validate_positive_integer() {
  value=$1
  name=$2
  case "$value" in
    ''|*[!0-9]*|0) fail "$name must be a positive integer" ;;
  esac
}

validate_label() {
  value=$1
  [ -n "$value" ] || fail "LABEL is required for this run"
  case "$value" in
    *[!A-Za-z0-9._+-]*)
      fail "LABEL may contain only letters, digits, dot, underscore, plus, and hyphen"
      ;;
  esac
}

preflight() {
  require_command git
  require_command awk
  require_command lscpu
  require_command python3
  require_command ifx
  require_command mpiifx
  require_command mpiicx
  require_command "$MPIRUN"
  validate_positive_integer "$CG_SD_OMP_NUM_THREADS" CG_SD_OMP_NUM_THREADS

  [ -n "$EXPECTED_SKU" ] || fail "set EXPECTED_SKU=6980P, 8468, or 8592+"
  case "$EXPECTED_SKU" in
    6980P|8468|8592+) ;;
    *) fail "EXPECTED_SKU must be 6980P, 8468, or 8592+" ;;
  esac

  cd "$ROOT_DIR"
  detect_sku
  [ "$detected_sku" = "$EXPECTED_SKU" ] ||
    fail "CPU mismatch: expected $EXPECTED_SKU, detected $detected_sku"
  set_fixed_configuration

  EXPECTED_SKU="$EXPECTED_SKU" EXPECTED_REVISION="$EXPECTED_REVISION" \
    FFTW_ROOT="$FFTW_ROOT" "$SCRIPT_DIR/check_cb3x3x3_x86_environment.sh"
  "$SCRIPT_DIR/check_cb3x3x3_benchmark.sh"

  revision=$(git rev-parse HEAD)
  short_revision=$(git rev-parse --short=12 HEAD)
  host_name=$(hostname -s 2>/dev/null || hostname)
  platform_id=$(printf '%s_%s' "$detected_sku" "$host_name" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  PLATFORM_ROOT=$BENCHMARK_ROOT/platforms/$platform_id
  PLATFORM_BIN=$PLATFORM_ROOT/bin
  PLATFORM_RUNS=$PLATFORM_ROOT/runs
}

release_build_lock() {
  if [ -n "${build_lock:-}" ] && [ -d "$build_lock" ]; then
    rmdir "$build_lock" 2>/dev/null || true
  fi
}

build_binaries() {
  mkdir -p "$ROOT_DIR/.cache" "$PLATFORM_BIN" "$PLATFORM_RUNS"
  build_lock=$ROOT_DIR/.cache/cb3x3x3_x86_build.lock
  if ! mkdir "$build_lock" 2>/dev/null; then
    fail "another cb3x3x3 x86 build appears active: $build_lock"
  fi
  trap release_build_lock EXIT HUP INT TERM

  BUILD_ONLY=1 TOOLCHAIN=intel RUNS=1 \
    NPROCS="$NPROCS" OMP_NUM_THREADS="$TDDFT_OMP_NUM_THREADS" \
    BUILD_MODE="$BUILD_MODE" SKIP_FFTW=1 FFTW_ROOT="$FFTW_ROOT" \
    "$SCRIPT_DIR/run_tddft_x86_baseline.sh"

  for pair in \
    "FPSEID21/cg_GGA_f_code/cg_exe cg_exe" \
    "FPSEID21/sd_GGA_f_compact_code/sd_exe sd_exe" \
    "FPSEID21/tddft_2022October/tddft_exe tddft_exe"
  do
    set -- $pair
    require_nonempty "$ROOT_DIR/$1"
    part=$PLATFORM_BIN/$2.part.$$
    cp -p "$ROOT_DIR/$1" "$part"
    mv "$part" "$PLATFORM_BIN/$2"
  done

  {
    echo "revision=$revision"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "detected_sku=$detected_sku"
    echo "nprocs=$NPROCS"
    echo "tddft_omp_num_threads=$TDDFT_OMP_NUM_THREADS"
    echo "cg_sd_omp_num_threads=$CG_SD_OMP_NUM_THREADS"
    echo "fftw_root=$FFTW_ROOT"
    echo "diagnostic=OFF"
    echo "ifx=$({ ifx --version 2>/dev/null || true; } | first_nonblank_line)"
    echo "mpiifx=$({ mpiifx --version 2>/dev/null || true; } | first_nonblank_line)"
    echo "mpirun=$({ "$MPIRUN" --version 2>/dev/null || true; } | first_nonblank_line)"
    echo "cg_exe_sha256=$(sha256_file "$PLATFORM_BIN/cg_exe")"
    echo "sd_exe_sha256=$(sha256_file "$PLATFORM_BIN/sd_exe")"
    echo "tddft_exe_sha256=$(sha256_file "$PLATFORM_BIN/tddft_exe")"
  } > "$PLATFORM_BIN/BUILD_PROVENANCE.env"

  release_build_lock
  trap - EXIT HUP INT TERM
  echo "build_gate=PASS"
  echo "platform_bin=$PLATFORM_BIN"
}

run_cg() {
  out=$CG_DIR/dia-cb3x3x3.out
  err=$CG_DIR/dia-cb3x3x3.err
  for path in \
    "$out" "$err" "$CG_DIR/fort.23" "$CG_DIR/fort.24" "$CG_DIR/fort.88" \
    "$CG_DIR/rh.dia-cb3x3x3_new" \
    "$CG_DIR/wf_fft.dia-cb3x3x3_new" \
    "$CG_DIR/wf_real.dia-cb3x3x3" "$CG_DIR/CG_PROVENANCE.env"
  do
    [ ! -e "$path" ] && [ ! -L "$path" ] ||
      fail "CG output already exists; refusing to overwrite: $path"
  done

  echo "Running cb3x3x3 CG with OMP_NUM_THREADS=$CG_SD_OMP_NUM_THREADS"
  (
    cd "$CG_DIR"
    ulimit -s unlimited 2>/dev/null || true
    OMP_NUM_THREADS="$CG_SD_OMP_NUM_THREADS" OMP_STACKSIZE="$OMP_STACKSIZE" \
      "$PLATFORM_BIN/cg_exe" < dia-cb3x3x3.in \
      > dia-cb3x3x3.out 2> dia-cb3x3x3.err
  )

  check_log cg "$out" "$err"
  require_nonempty "$CG_DIR/fort.24"
  require_nonempty "$CG_DIR/fort.23"
  require_nonempty "$CG_DIR/fort.88"
  copy_new "$CG_DIR/fort.24" "$CG_DIR/rh.dia-cb3x3x3_new" "CG density"
  copy_new "$CG_DIR/fort.23" "$CG_DIR/wf_fft.dia-cb3x3x3_new" "CG reciprocal wavefunction"
  copy_new "$CG_DIR/fort.88" "$CG_DIR/wf_real.dia-cb3x3x3" "CG real-space wavefunction"

  {
    echo "revision=$revision"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "sku=$detected_sku"
    echo "omp_num_threads=$CG_SD_OMP_NUM_THREADS"
    echo "executable_sha256=$(sha256_file "$PLATFORM_BIN/cg_exe")"
    echo "input_sha256=$(sha256_file "$CG_DIR/dia-cb3x3x3.in")"
    echo "density_sha256=$(sha256_file "$CG_DIR/rh.dia-cb3x3x3_new")"
    echo "wf_fft_sha256=$(sha256_file "$CG_DIR/wf_fft.dia-cb3x3x3_new")"
    echo "wf_real_sha256=$(sha256_file "$CG_DIR/wf_real.dia-cb3x3x3")"
    echo "cg_check=PASS"
  } > "$CG_DIR/CG_PROVENANCE.env"

  echo "CG_RESULT_PASS"
  echo "cg_dir=$CG_DIR"
  echo "next_action=review_then_run_sd"
}

run_sd() {
  require_nonempty "$CG_DIR/CG_PROVENANCE.env"
  require_nonempty "$CG_DIR/rh.dia-cb3x3x3_new"
  require_nonempty "$CG_DIR/wf_fft.dia-cb3x3x3_new"
  require_nonempty "$CG_DIR/wf_real.dia-cb3x3x3"
  cg_host=$(awk -F= '$1 == "hostname" {print substr($0, index($0, "=") + 1); exit}' \
    "$CG_DIR/CG_PROVENANCE.env")
  cg_revision=$(awk -F= '$1 == "revision" {print $2; exit}' \
    "$CG_DIR/CG_PROVENANCE.env")
  [ "$cg_host" = "$host_name" ] ||
    fail "SD must run on the CG state-generation host: CG=$cg_host current=$host_name"
  [ "$cg_revision" = "$revision" ] ||
    fail "CG revision differs from the current revision: CG=$cg_revision current=$revision"

  out=$SD_DIR/dia-cb3x3x3_sd.out
  err=$SD_DIR/dia-cb3x3x3_sd.err
  for path in \
    "$out" "$err" "$SD_DIR/fort.20" "$SD_DIR/fort.22" "$SD_DIR/fort.88" \
    "$SD_DIR/fort.23" "$SD_DIR/fort.24" \
    "$SD_DIR/rh.dia-cb3x3x3" "$SD_DIR/wf_fft.dia-cb3x3x3" \
    "$SD_DIR/wf_real.dia-cb3x3x3" "$SD_DIR/rh.dia-cb3x3x3_new" \
    "$SD_DIR/wf_fft.dia-cb3x3x3_new" "$SD_DIR/SD_PROVENANCE.env"
  do
    [ ! -e "$path" ] && [ ! -L "$path" ] ||
      fail "SD path already exists; refusing to overwrite: $path"
  done

  copy_new "$CG_DIR/rh.dia-cb3x3x3_new" \
    "$SD_DIR/rh.dia-cb3x3x3" "SD input density"
  copy_new "$CG_DIR/wf_fft.dia-cb3x3x3_new" \
    "$SD_DIR/wf_fft.dia-cb3x3x3" "SD input reciprocal wavefunction"
  copy_new "$CG_DIR/wf_real.dia-cb3x3x3" \
    "$SD_DIR/wf_real.dia-cb3x3x3" "SD input real-space wavefunction"
  link_new rh.dia-cb3x3x3 "$SD_DIR/fort.20"
  link_new wf_fft.dia-cb3x3x3 "$SD_DIR/fort.22"
  link_new wf_real.dia-cb3x3x3 "$SD_DIR/fort.88"

  echo "Running cb3x3x3 SD with OMP_NUM_THREADS=$CG_SD_OMP_NUM_THREADS"
  (
    cd "$SD_DIR"
    ulimit -s unlimited 2>/dev/null || true
    OMP_NUM_THREADS="$CG_SD_OMP_NUM_THREADS" OMP_STACKSIZE="$OMP_STACKSIZE" \
      "$PLATFORM_BIN/sd_exe" < dia-cb3x3x3_sd.in \
      > dia-cb3x3x3_sd.out 2> dia-cb3x3x3_sd.err
  )

  check_log sd "$out" "$err"
  require_nonempty "$SD_DIR/fort.24"
  require_nonempty "$SD_DIR/fort.23"
  copy_new "$SD_DIR/fort.24" "$SD_DIR/rh.dia-cb3x3x3_new" "SD density"
  copy_new "$SD_DIR/fort.23" "$SD_DIR/wf_fft.dia-cb3x3x3_new" "SD full-grid wavefunction"

  for path in \
    "$STATE_DIR/rh.dia-cb3x3x3" "$STATE_DIR/wf_fft.dia-cb3x3x3" \
    "$STATE_DIR/STATE_MANIFEST.sha256" "$STATE_DIR/STATE_PROVENANCE.env" \
    "$STATE_DIR/fort.20" "$STATE_DIR/fort.22" "$STATE_DIR/fort.32"
  do
    [ ! -e "$path" ] && [ ! -L "$path" ] ||
      fail "canonical TDDFT state already exists; refusing to overwrite: $path"
  done

  copy_new "$SD_DIR/rh.dia-cb3x3x3_new" \
    "$STATE_DIR/rh.dia-cb3x3x3" "canonical TDDFT density"
  copy_new "$SD_DIR/wf_fft.dia-cb3x3x3_new" \
    "$STATE_DIR/wf_fft.dia-cb3x3x3" "canonical TDDFT wavefunction"
  chmod a-w "$STATE_DIR/rh.dia-cb3x3x3" "$STATE_DIR/wf_fft.dia-cb3x3x3"

  (
    cd "$STATE_DIR"
    {
      echo "$(sha256_file rh.dia-cb3x3x3)  rh.dia-cb3x3x3"
      echo "$(sha256_file wf_fft.dia-cb3x3x3)  wf_fft.dia-cb3x3x3"
    } > STATE_MANIFEST.sha256
    chmod a-w STATE_MANIFEST.sha256
  )
  link_new rh.dia-cb3x3x3 "$STATE_DIR/fort.20"
  link_new wf_fft.dia-cb3x3x3 "$STATE_DIR/fort.22"
  link_new wf_fft.dia-cb3x3x3 "$STATE_DIR/fort.32"

  {
    echo "revision=$revision"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "sku=$detected_sku"
    echo "omp_num_threads=$CG_SD_OMP_NUM_THREADS"
    echo "executable_sha256=$(sha256_file "$PLATFORM_BIN/sd_exe")"
    echo "input_sha256=$(sha256_file "$SD_DIR/dia-cb3x3x3_sd.in")"
    echo "cg_provenance_sha256=$(sha256_file "$CG_DIR/CG_PROVENANCE.env")"
    echo "density_sha256=$(sha256_file "$STATE_DIR/rh.dia-cb3x3x3")"
    echo "wf_fft_sha256=$(sha256_file "$STATE_DIR/wf_fft.dia-cb3x3x3")"
    echo "sd_check=PASS"
  } > "$SD_DIR/SD_PROVENANCE.env"
  cp -p "$SD_DIR/SD_PROVENANCE.env" "$STATE_DIR/STATE_PROVENANCE.env"
  chmod a-w "$STATE_DIR/STATE_PROVENANCE.env"

  "$SCRIPT_DIR/check_cb3x3x3_benchmark.sh"
  echo "SD_RESULT_PASS"
  echo "state_dir=$STATE_DIR"
  echo "state_manifest=$STATE_DIR/STATE_MANIFEST.sha256"
  echo "next_action=review_then_run_tddft-2"
}

prepare_tddft_run_dir() {
  run_dir=$1
  input_name=$2
  mkdir -p "$run_dir"

  for rel in \
    "$input_name" SOURCE_MANIFEST.env TR.C95g_asci \
    Avec Cartesian.velo Eext Etot Ework laser.dat size.dat sym.C1
  do
    require_file "$STATE_DIR/$rel"
    cp -p "$STATE_DIR/$rel" "$run_dir/$rel"
  done
  require_nonempty "$STATE_DIR/rh.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/wf_fft.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/STATE_MANIFEST.sha256"
  cp -p "$STATE_DIR/STATE_MANIFEST.sha256" "$run_dir/STATE_MANIFEST.sha256"

  # Hard links avoid duplicating the multi-gigabyte immutable input state in
  # the live run directory. The case-specific archive still copies the actual
  # files so each accepted archive is self-contained.
  ln "$STATE_DIR/rh.dia-cb3x3x3" "$run_dir/rh.dia-cb3x3x3"
  ln "$STATE_DIR/wf_fft.dia-cb3x3x3" "$run_dir/wf_fft.dia-cb3x3x3"
  link_new rh.dia-cb3x3x3 "$run_dir/fort.20"
  link_new wf_fft.dia-cb3x3x3 "$run_dir/fort.22"
  link_new wf_fft.dia-cb3x3x3 "$run_dir/fort.32"
  link_new TR.C95g_asci "$run_dir/fort.41"
  link_new Eext "$run_dir/fort.18"
  link_new Etot "$run_dir/fort.28"
  link_new laser.dat "$run_dir/fort.53"
  link_new size.dat "$run_dir/fort.54"
  link_new sym.C1 "$run_dir/fort.55"
  link_new Avec "$run_dir/fort.60"
  link_new Ework "$run_dir/fort.62"
}

run_tddft() {
  steps=$1
  input_name=dia-cb3x3x3_tm.in_${steps}steps
  reference=

  case "$steps" in
    2)
      timestamp=$(date '+%Y%m%d_%H%M%S')
      run_label=${LABEL:-"cb3x3x3_${platform_id}_${NPROCS}mpi_${TDDFT_OMP_NUM_THREADS}omp_2step_${timestamp}_${short_revision}"}
      ;;
    100)
      [ "$CONFIRM_LONG_RUN" = YES ] ||
        fail "set CONFIRM_LONG_RUN=YES for a 100-step diagnostic run"
      validate_label "${LABEL:-}"
      run_label=$LABEL
      ;;
    1000)
      [ "$CONFIRM_LONG_RUN" = YES ] ||
        fail "set CONFIRM_LONG_RUN=YES for a 1000-step run"
      validate_label "${LABEL:-}"
      [ -n "${REFERENCE_OUTPUT:-}" ] ||
        fail "set REFERENCE_OUTPUT to an approved same-input 1000-step output"
      require_file "$REFERENCE_OUTPUT"
      reference=$REFERENCE_OUTPUT
      run_label=$LABEL
      ;;
    40000)
      [ "$CONFIRM_LONG_RUN" = YES ] ||
        fail "set CONFIRM_LONG_RUN=YES for a 40000-step run"
      validate_label "${LABEL:-}"
      reference=$BENCHMARK_ROOT/official/600K/dia-cb3x3x3_tm.out_AOBA-S
      require_file "$reference"
      run_label=$LABEL
      ;;
    *) fail "unsupported TDDFT step count: $steps" ;;
  esac
  validate_label "$run_label"

  run_dir=$PLATFORM_RUNS/$run_label
  archive_dir=$BENCHMARK_ROOT/archives/$run_label
  [ ! -e "$run_dir" ] || fail "run directory already exists: $run_dir"
  [ ! -e "$archive_dir" ] || fail "archive already exists: $archive_dir"
  prepare_tddft_run_dir "$run_dir" "$input_name"

  {
    echo "revision=$revision"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "sku=$detected_sku"
    echo "steps=$steps"
    echo "nprocs=$NPROCS"
    echo "omp_num_threads=$TDDFT_OMP_NUM_THREADS"
    echo "omp_stacksize=$OMP_STACKSIZE"
    echo "i_mpi_pin=1"
    echo "i_mpi_pin_domain=omp"
    echo "i_mpi_pin_order=compact"
    echo "kmp_affinity=granularity=fine,compact,1,0"
    echo "diagnostic=OFF"
    echo "tddft_executable_sha256=$(sha256_file "$PLATFORM_BIN/tddft_exe")"
    echo "state_manifest_sha256=$(sha256_file "$run_dir/STATE_MANIFEST.sha256")"
    echo "reference_output=$reference"
  } > "$run_dir/RUN_PROVENANCE.env"

  echo "Running cb3x3x3 TDDFT: steps=$steps MPI=$NPROCS OpenMP=$TDDFT_OMP_NUM_THREADS"
  (
    cd "$run_dir"
    ulimit -s unlimited 2>/dev/null || true
    export OMP_NUM_THREADS="$TDDFT_OMP_NUM_THREADS"
    export OMP_STACKSIZE
    export I_MPI_PIN=1
    export I_MPI_PIN_DOMAIN=omp
    export I_MPI_PIN_ORDER=compact
    export KMP_AFFINITY=granularity=fine,compact,1,0
    "$MPIRUN" -np "$NPROCS" "$PLATFORM_BIN/tddft_exe" \
      < "$input_name" > dia-cb3x3x3_tm.out 2> dia-cb3x3x3_tm.err
  )

  python3 "$SCRIPT_DIR/check_tddft_result.py" check \
    "$run_dir/dia-cb3x3x3_tm.out" \
    --err "$run_dir/dia-cb3x3x3_tm.err" \
    --expected-steps "$steps"

  if [ "$steps" -eq 2 ] || [ "$steps" -eq 100 ]; then
    if [ "$steps" -eq 2 ]; then
      echo "CB3X3X3_TDDFT_STARTUP_PASS"
    else
      echo "CB3X3X3_TDDFT_DIAGNOSTIC_PASS"
    fi
    echo "run_dir=$run_dir"
    echo "normal_check=PASS"
    echo "same_input_compare=NOT_AVAILABLE"
    echo "baseline=NOT_APPLICABLE"
    return 0
  fi

  EXPECTED_STEPS="$steps" REFERENCE_OUTPUT="$reference" LABEL="$run_label" \
    RUN_DIR="$run_dir" "$SCRIPT_DIR/archive_cb3x3x3_result.sh"
  echo "CB3X3X3_TDDFT_RUN_PASS"
  echo "run_dir=$run_dir"
  echo "archive=$archive_dir"
  echo "normal_check=PASS"
  echo "same_input_compare=PASS"
}

case "$ACTION" in
  -h|--help|help|'')
    usage
    [ -n "$ACTION" ] || exit 2
    exit 0
    ;;
  build|cg|sd|tddft-2|tddft-100|tddft-1000|tddft-40000) ;;
  *) usage >&2; fail "unknown action: $ACTION" ;;
esac

preflight
build_binaries

echo "FPSEID21_CB3X3X3_X86_RUN_BEGIN"
echo "action=$ACTION"
echo "revision=$revision"
echo "hostname=$host_name"
echo "sku=$detected_sku"
echo "nprocs=$NPROCS"
echo "tddft_omp_num_threads=$TDDFT_OMP_NUM_THREADS"
echo "cg_sd_omp_num_threads=$CG_SD_OMP_NUM_THREADS"
echo "diagnostic=OFF"

case "$ACTION" in
  build) ;;
  cg) run_cg ;;
  sd) run_sd ;;
  tddft-2) run_tddft 2 ;;
  tddft-100) run_tddft 100 ;;
  tddft-1000) run_tddft 1000 ;;
  tddft-40000) run_tddft 40000 ;;
esac

echo "FPSEID21_CB3X3X3_X86_RUN_END"
