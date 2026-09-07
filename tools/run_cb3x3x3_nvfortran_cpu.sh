#!/bin/sh
set -eu

# Bounded compiler-isolation diagnostic for the official diamond cb3x3x3
# case. Build the CPU/FFTW path with NVFORTRAN, run exactly two steps on the
# Xeon 8468 host paired with the H100, and compare with the fixed ifx result.
# This helper intentionally exposes no long-run action.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

ACTION=${1:-}
EXPECTED_SKU=${EXPECTED_SKU:-8468}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
STATE_DIR=${STATE_DIR:-"$BENCHMARK_ROOT/work/tddft_600K"}
NVFORTRAN_PLATFORM_ROOT=${NVFORTRAN_PLATFORM_ROOT:-}
NVFORTRAN_FFTW_ROOT=${NVFORTRAN_FFTW_ROOT:-}
X86_2STEP_REFERENCE=${X86_2STEP_REFERENCE:-"$BENCHMARK_ROOT/platforms/8592p_spr10/runs/cb3x3x3_8592p_spr10_32mpi_4omp_2step_20260827_170605_6ddf5ff11ecc"}
NPROCS=32
OMP_NUM_THREADS=3
MIN_AVAILABLE_GIB=768
STANDARD_CPU_FLAGS="-O2 -mp -Msave -Mlarge_arrays"
RUNTIME_CHECK_FLAGS="-O0 -g -traceback -mp -Msave -Mlarge_arrays -Mbounds -Mchkptr -Mchkstk -Minit-real=snan -Minit-integer=2147483647"
case "$ACTION" in
  preflight-runtime-checks|tddft-2-runtime-checks)
    BUILD_VARIANT=runtime_checks
    CPU_FLAGS=$RUNTIME_CHECK_FLAGS
    RUNTIME_CHECKS=ON
    ;;
  *)
    BUILD_VARIANT=standard
    CPU_FLAGS=$STANDARD_CPU_FLAGS
    RUNTIME_CHECKS=OFF
    ;;
esac
# Use FFTW's POSIX-thread backend so the executable contains only NVHPC's
# OpenMP runtime. Linking GCC libgomp beside NVHPC libnvomp would add an
# avoidable runtime variable to this compiler-isolation experiment.
FFTW_LIBS="-lfftw3_threads -lfftw3 -lpthread"
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
NVFORTRAN=${NVFORTRAN:-nvfortran}
MPI_FC=${MPI_FC:-mpifort}
MPI_CC=${MPI_CC:-mpicc}
MPIRUN=${MPIRUN:-mpirun}
FFTW_CC=${FFTW_CC:-gcc}
FFTW_FC=${FFTW_FC:-gfortran}
FFTW_F77=${FFTW_F77:-$FFTW_FC}
COST_DISTRIBUTION=${COST_DISTRIBUTION:-0}
COST_PLATFORM=${COST_PLATFORM:-XEON_8468_NVFORTRAN_CPU_FFTW_32MPI_3OMP}
COST_DETAIL_TIMERS=${COST_DETAIL_TIMERS:-0}
case "$COST_DETAIL_TIMERS" in
  0|1) ;;
  *)
    echo "ERROR: COST_DETAIL_TIMERS must be 0 or 1" >&2
    exit 1
    ;;
esac
if [ "$BUILD_VARIANT" = standard ] && [ "$COST_DETAIL_TIMERS" = 1 ]; then
  BUILD_VARIANT=cost_detail
fi

usage() {
  cat <<'EOF'
Usage: ./tools/run_cb3x3x3_nvfortran_cpu.sh ACTION

Actions:
  preflight  Read-only Git, input/state, CPU/memory, NVFORTRAN/Open MPI,
             reference, and FFTW readiness checks. No build or simulation.
  tddft-2    Re-run preflight, build an isolated NVFORTRAN CPU/FFTW TDDFT
             executable, run 32 MPI x 3 OpenMP for exactly two steps, and
             relaxed-compare with the fixed Xeon 8592+ ifx result.
  preflight-runtime-checks
             Read-only preflight for the separately built runtime-check
             diagnostic. No build or simulation.
  tddft-2-runtime-checks
             Build and run a separately isolated two-step executable with
             bounds, NULL-pointer, stack, traceback, and local-variable
             initialization diagnostics enabled. Floating-point traps are
             excluded because they abort inside Open MPI/UCX initialization.

This diagnostic is fixed to a dual-socket Xeon Platinum 8468 with at least
96 physical cores and 768 GiB MemAvailable. OpenACC and GPU use are disabled.
There is deliberately no 100-step action and no baseline-adoption path.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    fail "required command was not found: $1"
}

require_file() {
  [ -f "$1" ] || fail "required file is missing: $1"
}

require_nonempty() {
  [ -s "$1" ] || fail "required file is missing or empty: $1"
}

first_nonblank_line() {
  awk 'NF {print; exit}'
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

git_repo() {
  git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" "$@"
}

validate_label() {
  case "$1" in
    ''|*[!A-Za-z0-9._+-]*)
      fail "LABEL may contain only letters, digits, dot, underscore, plus, and hyphen"
      ;;
  esac
}

copy_text_lf_new() {
  source_file=$1
  destination_file=$2
  [ ! -e "$destination_file" ] && [ ! -L "$destination_file" ] ||
    fail "path already exists; refusing to overwrite: $destination_file"
  LC_ALL=C tr -d '\r' < "$source_file" > "$destination_file"
}

link_new() {
  target=$1
  link=$2
  [ ! -e "$link" ] && [ ! -L "$link" ] ||
    fail "path already exists; refusing to overwrite: $link"
  ln -s "$target" "$link"
}

verify_state() {
  require_nonempty "$STATE_DIR/rh.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/wf_fft.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/STATE_MANIFEST.sha256"
  require_file "$STATE_DIR/STATE_PROVENANCE.env"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$STATE_DIR" && sha256sum -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "TDDFT initial-state SHA-256 validation failed"
  else
    (cd "$STATE_DIR" && shasum -a 256 -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "TDDFT initial-state SHA-256 validation failed"
  fi
}

runtime_library_path() {
  runtime_dirs=
  for runtime_name in libgomp.so.1 libatomic.so.1; do
    runtime_file=$("$FFTW_CC" -print-file-name="$runtime_name" 2>/dev/null || true)
    case "$runtime_file" in
      */"$runtime_name")
        runtime_dir=$(dirname -- "$runtime_file")
        case ":$runtime_dirs:" in
          *":$runtime_dir:"*) ;;
          *) runtime_dirs=${runtime_dirs:+$runtime_dirs:}$runtime_dir ;;
        esac
        ;;
    esac
  done
  printf '%s\n' "$runtime_dirs"
}

release_build_lock() {
  if [ -n "${build_lock:-}" ] && [ -d "$build_lock" ]; then
    rmdir "$build_lock" 2>/dev/null || true
  fi
}

preflight() {
  for command_name in git awk grep sort tr tar ldd lscpu python3 "$NVFORTRAN" \
    "$MPI_FC" "$MPI_CC" "$MPIRUN" "$FFTW_CC" "$FFTW_FC"; do
    require_command "$command_name"
  done

  [ "$(uname -s)" = Linux ] || fail "NVFORTRAN CPU execution requires Linux"
  case "$(uname -m)" in
    x86_64|amd64) ;;
    *) fail "x86-64 is required; detected $(uname -m)" ;;
  esac
  [ "$EXPECTED_SKU" = 8468 ] ||
    fail "this bounded diagnostic requires EXPECTED_SKU=8468"

  cpu_model=$(lscpu | awk -F: '/Model name/ {
    sub(/^[[:space:]]+/, "", $2); print $2; exit
  }')
  case "$cpu_model" in
    *8468*) detected_sku=8468 ;;
    *) fail "expected Xeon Platinum 8468, detected: $cpu_model" ;;
  esac
  socket_count=$(lscpu -p=Socket 2>/dev/null |
    awk -F, '!/^#/ {seen[$1]=1} END {print length(seen)}')
  physical_cores=$(lscpu -p=Core,Socket 2>/dev/null |
    awk -F, '!/^#/ {seen[$1 ":" $2]=1} END {print length(seen)}')
  logical_cpus=$(lscpu -p=CPU 2>/dev/null |
    awk -F, '!/^#/ {count++} END {print count+0}')
  [ "$socket_count" -eq 2 ] ||
    fail "two CPU sockets are required; detected $socket_count"
  [ "$physical_cores" -ge 96 ] ||
    fail "at least 96 physical cores are required; detected $physical_cores"
  case "${SLURM_CPUS_ON_NODE:-}" in
    '') ;;
    *[!0-9]*) ;;
    *)
      [ "$SLURM_CPUS_ON_NODE" -ge 96 ] ||
        fail "Slurm exposes only $SLURM_CPUS_ON_NODE CPUs; require at least 96"
      ;;
  esac

  [ -r /proc/meminfo ] || fail "/proc/meminfo is not readable"
  mem_total_kib=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
  mem_available_kib=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
  [ -n "$mem_total_kib" ] && [ -n "$mem_available_kib" ] ||
    fail "MemTotal or MemAvailable is missing from /proc/meminfo"
  mem_total_gib=$(awk -v kib="$mem_total_kib" \
    'BEGIN {printf "%.2f", kib/1048576}')
  mem_available_gib=$(awk -v kib="$mem_available_kib" \
    'BEGIN {printf "%.2f", kib/1048576}')
  awk -v have="$mem_available_gib" -v need="$MIN_AVAILABLE_GIB" \
    'BEGIN {exit !(have >= need)}' ||
    fail "MemAvailable is ${mem_available_gib} GiB; require at least ${MIN_AVAILABLE_GIB} GiB"

  [ "$(git_repo branch --show-current)" = tddft-openacc-residency ] ||
    fail "checkout tddft-openacc-residency first"
  git_repo diff --quiet || fail "tracked worktree is not clean"
  git_repo diff --cached --quiet || fail "Git index is not clean"
  set -- $(git_repo rev-list --left-right --count \
    origin/tddft-openacc-residency...HEAD)
  [ "$1" = 0 ] && [ "$2" = 0 ] ||
    fail "local branch and origin/tddft-openacc-residency are not synchronized"

  "$SCRIPT_DIR/check_cb3x3x3_benchmark.sh" >/dev/null
  require_file "$STATE_DIR/dia-cb3x3x3_tm.in_2steps"
  grep -Eq 'tstep=2([[:space:]]|$)' \
    "$STATE_DIR/dia-cb3x3x3_tm.in_2steps" ||
    fail "2-step input has the wrong tstep"
  verify_state
  require_nonempty "$X86_2STEP_REFERENCE/dia-cb3x3x3_tm.out"

  nvfortran_version=$("$NVFORTRAN" -V 2>&1 | first_nonblank_line || true)
  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    runtime_check_flag_gate=DEFERRED_TO_BUILD_COMPILE_PROBE
  else
    runtime_check_flag_gate=NOT_APPLICABLE
  fi
  mpi_fc_version=$("$MPI_FC" --version 2>&1 | first_nonblank_line || true)
  mpi_fc_backend=$("$MPI_FC" --showme:command 2>/dev/null || true)
  case "$mpi_fc_backend $mpi_fc_version" in
    *nvfortran*) ;;
    *) fail "$MPI_FC is not backed by NVFORTRAN: $mpi_fc_backend" ;;
  esac
  mpirun_version=$("$MPIRUN" --version 2>&1 | first_nonblank_line || true)
  case "$mpirun_version" in
    *Open\ MPI*) ;;
    *) fail "this runner requires Open MPI; detected: $mpirun_version" ;;
  esac

  revision=$(git_repo rev-parse HEAD)
  short_revision=$(git_repo rev-parse --short=12 HEAD)
  host_name=$(hostname -s 2>/dev/null || hostname)
  platform_id=$(printf 'nvfortran_cpu_%s_%s' "$detected_sku" "$host_name" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  if [ -n "$NVFORTRAN_PLATFORM_ROOT" ]; then
    PLATFORM_ROOT=$NVFORTRAN_PLATFORM_ROOT
  else
    PLATFORM_ROOT=$BENCHMARK_ROOT/platforms/$platform_id
  fi
  case "$BUILD_VARIANT" in
    runtime_checks) PLATFORM_BIN=$PLATFORM_ROOT/bin/runtime_checks/$short_revision ;;
    cost_detail) PLATFORM_BIN=$PLATFORM_ROOT/bin/cost_detail/$short_revision ;;
    *) PLATFORM_BIN=$PLATFORM_ROOT/bin/$short_revision ;;
  esac
  PLATFORM_RUNS=$PLATFORM_ROOT/runs
  if [ -n "$NVFORTRAN_FFTW_ROOT" ]; then
    FFTW_ROOT=$NVFORTRAN_FFTW_ROOT
  else
    FFTW_ROOT=$PLATFORM_ROOT/deps/fftw-3.3.11-gcc-pthreads/install
  fi
  if [ -f "$FFTW_ROOT/include/fftw3.f" ] &&
     { [ -f "$FFTW_ROOT/lib/libfftw3.a" ] ||
       [ -f "$FFTW_ROOT/lib/libfftw3.so" ]; } &&
     { [ -f "$FFTW_ROOT/lib/libfftw3_threads.a" ] ||
       [ -f "$FFTW_ROOT/lib/libfftw3_threads.so" ]; }; then
    fftw_state=READY
  else
    fftw_state=NEEDS_ISOLATED_BUILD
  fi
  gcc_runtime_dirs=$(runtime_library_path)

  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    preflight_tag=FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_PREFLIGHT
  else
    preflight_tag=FPSEID21_CB3X3X3_NVFORTRAN_CPU_PREFLIGHT
  fi
  echo "${preflight_tag}_BEGIN"
  echo "revision=$revision"
  echo "accepted_numerical_source=c46cfa9"
  echo "hostname=$host_name"
  echo "cpu_model=$cpu_model"
  echo "detected_sku=$detected_sku"
  echo "sockets=$socket_count"
  echo "physical_cores=$physical_cores"
  echo "logical_cpus=$logical_cpus"
  echo "mem_total_gib=$mem_total_gib"
  echo "mem_available_gib=$mem_available_gib"
  echo "memory_gate_gib=$MIN_AVAILABLE_GIB"
  echo "configuration=${NPROCS}_MPI_${OMP_NUM_THREADS}_OpenMP_diagnostic_OFF"
  echo "build_variant=$BUILD_VARIANT"
  echo "runtime_checks=$RUNTIME_CHECKS"
  echo "cost_detail_timers=$COST_DETAIL_TIMERS"
  echo "compiler=$nvfortran_version"
  echo "mpi_compiler=$mpi_fc_version"
  echo "mpi_compiler_backend=$mpi_fc_backend"
  echo "mpirun=$mpirun_version"
  echo "flags=$CPU_FLAGS"
  echo "runtime_check_flag_gate=$runtime_check_flag_gate"
  echo "openacc=OFF"
  echo "fft_backend=fftw"
  echo "gpu_used=NO"
  echo "fftw_root=$FFTW_ROOT"
  echo "fftw_state=$fftw_state"
  echo "gcc_runtime_dirs=${gcc_runtime_dirs:-NOT_REQUIRED_OR_NOT_FOUND}"
  echo "state_dir=$STATE_DIR"
  echo "platform_root=$PLATFORM_ROOT"
  echo "x86_2step_reference=$X86_2STEP_REFERENCE"
  echo "slurm_job_id=${SLURM_JOB_ID:-NOT_SET}"
  echo "slurm_cpus_on_node=${SLURM_CPUS_ON_NODE:-NOT_SET}"
  echo "official_input_gate=PASS"
  echo "initial_state_sha256_gate=PASS"
  echo "reference_gate=PASS"
  echo "git_gate=PASS"
  echo "memory_gate=PASS"
  echo "preflight_gate=PASS"
  echo "${preflight_tag}_END"
}

prepare_fftw() {
  if [ "$fftw_state" = READY ]; then
    echo "Reusing isolated FFTW: $FFTW_ROOT"
    return 0
  fi
  for command_name in curl make tar; do
    require_command "$command_name"
  done
  fftw_work=$PLATFORM_ROOT/deps/build
  mkdir -p "$fftw_work"
  echo "Building isolated GCC FFTW for NVFORTRAN CPU diagnostic"
  WORK_DIR="$fftw_work" PREFIX="$FFTW_ROOT" CC="$FFTW_CC" \
    FC="$FFTW_FC" F77="$FFTW_F77" "$SCRIPT_DIR/build_fftw3.sh"
  require_nonempty "$FFTW_ROOT/include/fftw3.f"
  if [ ! -f "$FFTW_ROOT/lib/libfftw3.a" ] &&
     [ ! -f "$FFTW_ROOT/lib/libfftw3.so" ]; then
    fail "isolated FFTW build did not produce libfftw3"
  fi
  if [ ! -f "$FFTW_ROOT/lib/libfftw3_threads.a" ] &&
     [ ! -f "$FFTW_ROOT/lib/libfftw3_threads.so" ]; then
    fail "isolated FFTW build did not produce libfftw3_threads"
  fi
  fftw_state=READY
}

build_tddft() {
  mkdir -p "$ROOT_DIR/.cache" "$PLATFORM_BIN" "$PLATFORM_RUNS"
  executable=$PLATFORM_BIN/tddft_exe
  provenance=$PLATFORM_BIN/BUILD_PROVENANCE.env
  if [ -s "$executable" ] && [ -s "$provenance" ] &&
     grep -Fqx "revision=$revision" "$provenance" &&
     grep -Fqx "build_variant=$BUILD_VARIANT" "$provenance" &&
     grep -Fqx "runtime_checks=$RUNTIME_CHECKS" "$provenance" &&
     grep -Fqx "cost_detail_timers=$COST_DETAIL_TIMERS" "$provenance" &&
     grep -Fqx "compiler=$nvfortran_version" "$provenance" &&
     grep -Fqx "mpi_compiler_backend=$mpi_fc_backend" "$provenance" &&
     grep -Fqx "flags=$CPU_FLAGS" "$provenance" &&
     grep -Fqx "openacc=OFF" "$provenance" &&
     grep -Fqx "fft_backend=fftw" "$provenance" &&
     grep -Fqx "fftw_root=$FFTW_ROOT" "$provenance" &&
     grep -Fqx "fftw_libs=$FFTW_LIBS" "$provenance"; then
    echo "Reusing revision-specific NVFORTRAN CPU executable: $executable"
    echo "build_reused=1"
    echo "build_gate=PASS"
    echo "platform_bin=$PLATFORM_BIN"
    return 0
  fi
  [ ! -e "$executable" ] && [ ! -e "$provenance" ] ||
    fail "incomplete or mismatched revision-specific build already exists: $PLATFORM_BIN"

  build_lock=$ROOT_DIR/.cache/cb3x3x3_nvfortran_cpu_${BUILD_VARIANT}_build.lock
  if ! mkdir "$build_lock" 2>/dev/null; then
    fail "another cb3x3x3 NVFORTRAN CPU build appears active: $build_lock"
  fi
  trap release_build_lock EXIT HUP INT TERM

  prepare_fftw
  build_stamp=$(date '+%Y%m%d_%H%M%S')
  build_tree=$PLATFORM_ROOT/build/${BUILD_VARIANT}_${short_revision}_${build_stamp}_$$
  mkdir -p "$build_tree"
  git_repo archive HEAD FPSEID21/tddft_2022October | tar -x -C "$build_tree"
  source_dir=$build_tree/FPSEID21/tddft_2022October

  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    runtime_check_probe_log=$build_tree/runtime_check_flag_compile_probe.log
    runtime_check_probe_object=$build_tree/runtime_check_flag_compile_probe.o
    if "$MPI_FC" $CPU_FLAGS -Mpreprocess -c \
        "$source_dir/omp_clock.f" -o "$runtime_check_probe_object" \
        >"$runtime_check_probe_log" 2>&1; then
      echo "runtime_check_compile_probe=PASS"
    else
      probe_status=$?
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_BEGIN"
      echo "stage=runtime_check_flag_compile_probe"
      echo "outcome=BUILD_FLAG_REJECTED"
      echo "exit_status=$probe_status"
      echo "build_tree=$build_tree"
      echo "flags=$CPU_FLAGS"
      echo "probe_log_begin"
      tail -n 30 "$runtime_check_probe_log" 2>/dev/null || true
      echo "probe_log_end"
      echo "simulation_started=NO"
      echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_END"
      exit 1
    fi
  fi

  echo "Building isolated cb3x3x3 NVFORTRAN CPU/FFTW executable"
  build_status=0
  (
    cd "$source_dir"
    FC="$MPI_FC" CC="$MPI_CC" FFLAGS="$CPU_FLAGS" \
      FPSEID_FRPRMN_DIAGNOSTIC=0 FFT_BACKEND=fftw \
      FPSEID_COST_DETAIL_TIMERS="$COST_DETAIL_TIMERS" \
      FFTW_ROOT="$FFTW_ROOT" FFTW_LIBS="$FFTW_LIBS" ./mk_ifort.sh
  ) || build_status=$?
  if [ "$build_status" -ne 0 ]; then
    if [ "$BUILD_VARIANT" = runtime_checks ]; then
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_BEGIN"
      echo "stage=build"
      echo "outcome=BUILD_FAILURE"
      echo "exit_status=$build_status"
      echo "build_tree=$build_tree"
      echo "simulation_started=NO"
      echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_END"
    fi
    exit "$build_status"
  fi
  require_nonempty "$source_dir/tddft_exe"
  build_runtime_dirs=$(runtime_library_path)
  if [ -n "$build_runtime_dirs" ]; then
    build_ld_library_path=$build_runtime_dirs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  else
    build_ld_library_path=${LD_LIBRARY_PATH:-}
  fi
  ldd_output=$(LD_LIBRARY_PATH="$build_ld_library_path" \
    ldd "$source_dir/tddft_exe" 2>&1)
  if printf '%s\n' "$ldd_output" | grep -q 'not found'; then
    printf '%s\n' "$ldd_output" >&2
    fail "NVFORTRAN CPU executable has an unresolved shared library"
  fi
  if printf '%s\n' "$ldd_output" | grep -q 'libgomp'; then
    printf '%s\n' "$ldd_output" >&2
    fail "GCC libgomp is linked beside NVHPC OpenMP; compiler isolation is invalid"
  fi
  printf '%s\n' "$ldd_output" | grep -q 'libnvomp' || {
    printf '%s\n' "$ldd_output" >&2
    fail "NVHPC libnvomp was not found in the NVFORTRAN CPU executable"
  }

  cp -p "$source_dir/tddft_exe" "$executable"
  chmod a-w "$executable"
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "build_variant=$BUILD_VARIANT"
    echo "runtime_checks=$RUNTIME_CHECKS"
    echo "cost_detail_timers=$COST_DETAIL_TIMERS"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "sku=$detected_sku"
    echo "compiler=$nvfortran_version"
    echo "mpi_compiler=$mpi_fc_version"
    echo "mpi_compiler_backend=$mpi_fc_backend"
    echo "mpirun=$mpirun_version"
    echo "flags=$CPU_FLAGS"
    echo "openacc=OFF"
    echo "fft_backend=fftw"
    echo "gpu_used=NO"
    echo "fftw_root=$FFTW_ROOT"
    echo "fftw_libs=$FFTW_LIBS"
    echo "openmp_runtime=NVHPC_LIBNVOMP_ONLY"
    echo "build_source_tree=$build_tree"
    echo "build_reused=0"
    echo "diagnostic=OFF"
    echo "tddft_executable_sha256=$(sha256_file "$executable")"
  } > "$provenance"
  chmod a-w "$provenance"

  release_build_lock
  trap - EXIT HUP INT TERM
  echo "build_gate=PASS"
  echo "platform_bin=$PLATFORM_BIN"
}

prepare_run_dir() {
  run_dir=$1
  mkdir -p "$run_dir"
  for rel in \
    dia-cb3x3x3_tm.in_2steps TR.C95g_asci Avec Cartesian.velo \
    Eext Etot Ework laser.dat size.dat sym.C1
  do
    require_file "$STATE_DIR/$rel"
    copy_text_lf_new "$STATE_DIR/$rel" "$run_dir/$rel"
  done
  require_file "$STATE_DIR/SOURCE_MANIFEST.env"
  cp -p "$STATE_DIR/SOURCE_MANIFEST.env" "$run_dir/SOURCE_MANIFEST.env"
  cp -p "$STATE_DIR/STATE_MANIFEST.sha256" "$run_dir/STATE_MANIFEST.sha256"
  cp -p "$STATE_DIR/STATE_PROVENANCE.env" \
    "$run_dir/INPUT_STATE_PROVENANCE.env"
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

print_runtime_diagnostic_excerpt() {
  diagnostic_out=$1
  diagnostic_err=$2
  echo "runtime_diagnostic_lines_begin"
  (
    grep -Ei 'NVFORTRAN|NVFTN|subscript|bounds|NULL pointer|stack|SIGFPE|floating|arithmetic|segmentation|traceback|NaN|abort|error' \
      "$diagnostic_err" 2>/dev/null || true
    grep -Ei 'NVFORTRAN|NVFTN|subscript|bounds|NULL pointer|stack|SIGFPE|floating|arithmetic|segmentation|traceback|NaN|abort|error|current J' \
      "$diagnostic_out" 2>/dev/null || true
  ) | awk 'NF && !seen[$0]++ {print; count++; if (count >= 40) exit}'
  echo "runtime_diagnostic_lines_end"
  echo "stderr_tail_begin"
  tail -n 30 "$diagnostic_err" 2>/dev/null || true
  echo "stderr_tail_end"
}

run_two_steps() {
  timestamp=$(date '+%Y%m%d_%H%M%S')
  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    default_label="cb3x3x3_${platform_id}_${NPROCS}mpi_${OMP_NUM_THREADS}omp_runtime_checks_2step_${timestamp}_${short_revision}"
  elif [ "$BUILD_VARIANT" = cost_detail ]; then
    default_label="cb3x3x3_${platform_id}_${NPROCS}mpi_${OMP_NUM_THREADS}omp_cost_detail_2step_${timestamp}_${short_revision}"
  else
    default_label="cb3x3x3_${platform_id}_${NPROCS}mpi_${OMP_NUM_THREADS}omp_2step_${timestamp}_${short_revision}"
  fi
  run_label=${LABEL:-$default_label}
  validate_label "$run_label"
  run_dir=$PLATFORM_RUNS/$run_label
  [ ! -e "$run_dir" ] || fail "run directory already exists: $run_dir"

  build_tddft
  prepare_run_dir "$run_dir"
  executable=$PLATFORM_BIN/tddft_exe
  runtime_dirs=$(runtime_library_path)
  if [ -n "$runtime_dirs" ]; then
    effective_ld_library_path=$runtime_dirs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  else
    effective_ld_library_path=${LD_LIBRARY_PATH:-}
  fi
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "build_variant=$BUILD_VARIANT"
    echo "runtime_checks=$RUNTIME_CHECKS"
    echo "cost_detail_timers=$COST_DETAIL_TIMERS"
    echo "hostname=$host_name"
    echo "cpu_model=$cpu_model"
    echo "sku=$detected_sku"
    echo "steps=2"
    echo "nprocs=$NPROCS"
    echo "omp_num_threads=$OMP_NUM_THREADS"
    echo "omp_stacksize=$OMP_STACKSIZE"
    echo "mpi_mapping=ppr:16:socket:PE=3"
    echo "mpi_binding=core"
    echo "omp_proc_bind=true"
    echo "omp_places=cores"
    echo "compiler=$nvfortran_version"
    echo "flags=$CPU_FLAGS"
    echo "openacc=OFF"
    echo "fft_backend=fftw"
    echo "fftw_libs=$FFTW_LIBS"
    echo "openmp_runtime=NVHPC_LIBNVOMP_ONLY"
    echo "gpu_used=NO"
    echo "diagnostic=OFF"
    echo "state_dir=$STATE_DIR"
    echo "platform_root=$PLATFORM_ROOT"
    echo "fortran_text_input_line_endings=LF"
    echo "source_input_sha256=$(sha256_file "$STATE_DIR/dia-cb3x3x3_tm.in_2steps")"
    echo "input_sha256=$(sha256_file "$run_dir/dia-cb3x3x3_tm.in_2steps")"
    echo "state_manifest_sha256=$(sha256_file "$run_dir/STATE_MANIFEST.sha256")"
    echo "state_provenance_sha256=$(sha256_file "$run_dir/INPUT_STATE_PROVENANCE.env")"
    echo "tddft_executable_sha256=$(sha256_file "$executable")"
    echo "reference_output=$X86_2STEP_REFERENCE/dia-cb3x3x3_tm.out"
  } > "$run_dir/RUN_PROVENANCE.env"

  echo "Running cb3x3x3 NVFORTRAN CPU: variant=$BUILD_VARIANT steps=2 MPI=$NPROCS OpenMP=$OMP_NUM_THREADS"
  run_status=0
  (
    cd "$run_dir"
    ulimit -s unlimited 2>/dev/null || true
    if [ "$BUILD_VARIANT" = runtime_checks ]; then
      ulimit -c 0 2>/dev/null || true
    fi
    export OMP_NUM_THREADS
    export OMP_STACKSIZE
    export OMP_PROC_BIND=true
    export OMP_PLACES=cores
    export CUDA_VISIBLE_DEVICES=
    export LD_LIBRARY_PATH="$effective_ld_library_path"
    "$MPIRUN" -np "$NPROCS" --map-by ppr:16:socket:PE=3 --bind-to core \
      "$executable" < dia-cb3x3x3_tm.in_2steps \
      > dia-cb3x3x3_tm.out 2> dia-cb3x3x3_tm.err
  ) || run_status=$?
  echo "$run_status" > "$run_dir/tddft_exit_status.txt"
  verify_state
  if [ "$run_status" -ne 0 ]; then
    if [ "$BUILD_VARIANT" = runtime_checks ]; then
      {
        echo "exit_status=$run_status"
        echo "runtime_check_outcome=PROCESS_FAILURE_OR_TRAP"
        echo "normal_check=NOT_RUN"
        echo "relaxed_compare=NOT_RUN"
        echo "initial_state_postrun_sha256_gate=PASS"
        echo "baseline=NOT_APPLICABLE"
      } >> "$run_dir/RUN_PROVENANCE.env"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_BEGIN"
      echo "stage=run"
      echo "outcome=PROCESS_FAILURE_OR_TRAP"
      echo "exit_status=$run_status"
      echo "run_dir=$run_dir"
      print_runtime_diagnostic_excerpt \
        "$run_dir/dia-cb3x3x3_tm.out" "$run_dir/dia-cb3x3x3_tm.err"
      echo "initial_state_postrun_sha256_gate=PASS"
      echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_END"
    else
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_BEGIN"
      echo "stage=run"
      echo "exit_status=$run_status"
      echo "run_dir=$run_dir"
      echo "stderr_tail_begin"
      tail -n 20 "$run_dir/dia-cb3x3x3_tm.err" 2>/dev/null || true
      echo "stderr_tail_end"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_END"
    fi
    exit 1
  fi

  if ! check_summary=$(python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$run_dir/dia-cb3x3x3_tm.out" \
      --err "$run_dir/dia-cb3x3x3_tm.err" \
      --expected-steps 2 --expected-atoms 216 2>&1); then
    if [ "$BUILD_VARIANT" = runtime_checks ]; then
      {
        echo "exit_status=0"
        echo "runtime_check_outcome=NORMAL_CHECK_FAIL"
        echo "normal_check=FAIL"
        echo "relaxed_compare=NOT_RUN"
        echo "initial_state_postrun_sha256_gate=PASS"
        echo "baseline=NOT_APPLICABLE"
      } >> "$run_dir/RUN_PROVENANCE.env"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_BEGIN"
      echo "stage=normal_check"
      echo "outcome=NORMAL_CHECK_FAIL"
      echo "run_dir=$run_dir"
      printf '%s\n' "$check_summary"
      print_runtime_diagnostic_excerpt \
        "$run_dir/dia-cb3x3x3_tm.out" "$run_dir/dia-cb3x3x3_tm.err"
      echo "initial_state_postrun_sha256_gate=PASS"
      echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_END"
    else
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_BEGIN"
      echo "stage=normal_check"
      echo "run_dir=$run_dir"
      printf '%s\n' "$check_summary"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_END"
    fi
    exit 1
  fi
  printf '%s\n' "$check_summary"
  wall_sec=$(printf '%s\n' "$check_summary" | awk '
    /steps:/ {
      for (i=1; i<NF; i++) if ($i == "wall_sec:") value=$(i+1)
    }
    END {print value}
  ')
  [ -n "$wall_sec" ] || fail "normal-check summary did not contain wall_sec"

  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    test_platform=XEON_8468_NVFORTRAN_RUNTIME_CHECKS_32MPI_3OMP
  else
    test_platform=XEON_8468_NVFORTRAN_32MPI_3OMP
  fi
  if ! comparison_summary=$(EXPECTED_STEPS=2 EXPECTED_ATOMS=216 \
      REFERENCE_PLATFORM=XEON_8592P_IFX_32MPI_4OMP \
      TEST_PLATFORM="$test_platform" \
      "$SCRIPT_DIR/compare_cb3x3x3_platform_results.sh" \
      "$X86_2STEP_REFERENCE" "$run_dir" 2>&1); then
    {
      echo "wall_sec=$wall_sec"
      echo "normal_check=PASS"
      echo "relaxed_compare=FAIL"
      echo "initial_state_postrun_sha256_gate=PASS"
      echo "baseline=NOT_APPLICABLE"
    } >> "$run_dir/RUN_PROVENANCE.env"
    if [ "$BUILD_VARIANT" = runtime_checks ]; then
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_BEGIN"
      echo "stage=relaxed_compare"
      echo "outcome=RELAXED_COMPARE_FAIL"
      echo "run_dir=$run_dir"
      echo "comparison_output_begin"
      printf '%s\n' "$comparison_summary"
      echo "comparison_output_end"
      echo "initial_state_postrun_sha256_gate=PASS"
      echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT_END"
    else
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_BEGIN"
      echo "stage=relaxed_compare"
      echo "run_dir=$run_dir"
      echo "comparison_output_begin"
      printf '%s\n' "$comparison_summary"
      echo "comparison_output_end"
      echo "FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_FAILURE_END"
    fi
    exit 1
  fi
  printf '%s\n' "$comparison_summary"
  {
    echo "wall_sec=$wall_sec"
    echo "normal_check=PASS"
    echo "relaxed_compare=PASS"
    echo "initial_state_postrun_sha256_gate=PASS"
    echo "baseline=NOT_APPLICABLE"
  } >> "$run_dir/RUN_PROVENANCE.env"

  if [ "$BUILD_VARIANT" = runtime_checks ]; then
    result_tag=FPSEID21_CB3X3X3_NVFORTRAN_CPU_RUNTIME_CHECK_RESULT
    result_outcome=CORRECTNESS_PASS_NO_RUNTIME_VIOLATION_DETECTED
  else
    result_tag=FPSEID21_CB3X3X3_NVFORTRAN_CPU_2STEP_PASS
    result_outcome=CORRECTNESS_PASS
  fi
  echo "${result_tag}_BEGIN"
  echo "revision=$revision"
  echo "label=$run_label"
  echo "run_dir=$run_dir"
  echo "outcome=$result_outcome"
  echo "build_variant=$BUILD_VARIANT"
  echo "cost_detail_timers=$COST_DETAIL_TIMERS"
  echo "configuration=NVFORTRAN_CPU_FFTW_${NPROCS}_MPI_${OMP_NUM_THREADS}_OpenMP"
  echo "wall_sec=$wall_sec"
  echo "normal_check=PASS"
  echo "relaxed_compare=PASS"
  echo "initial_state_postrun_sha256_gate=PASS"
  echo "compiler_isolation_gate=PASS"
  echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
  echo "baseline=NOT_APPLICABLE"
  echo "${result_tag}_END"
  if [ "$COST_DISTRIBUTION" = 1 ]; then
    "$SCRIPT_DIR/report_cb3x3x3_2step_costs.sh" \
      "$run_dir/dia-cb3x3x3_tm.out" "$COST_PLATFORM" \
      "$COST_DETAIL_TIMERS"
  fi
}

case "$ACTION" in
  -h|--help|help|'')
    usage
    [ -n "$ACTION" ] || exit 2
    exit 0
    ;;
  preflight|tddft-2|preflight-runtime-checks|tddft-2-runtime-checks) ;;
  *) usage >&2; fail "unknown action: $ACTION" ;;
esac

preflight
case "$ACTION" in
  preflight|preflight-runtime-checks) ;;
  tddft-2|tddft-2-runtime-checks) run_two_steps ;;
esac
