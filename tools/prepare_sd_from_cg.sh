#!/bin/sh
set -eu

# Prepare a standalone SD run directory from an existing CG run result.
#
# Defaults:
#   CG_RUN_DIR=<repo>/run/Si111-H
#   RUN_DIR=<repo>/run/Si111-H_sd
#
# Example:
#   ./tools/prepare_sd_from_cg.sh
#   CG_RUN_DIR=run/Si111-H RUN_DIR=run/Si111-H_sd_nvhpc ./tools/prepare_sd_from_cg.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

CG_RUN_DIR=${CG_RUN_DIR:-"$ROOT_DIR/run/Si111-H"}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_sd"}
SD_EXE=${SD_EXE:-"$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe"}

copy_required() {
  src=$1
  dest=$2
  label=$3

  if [ ! -f "$src" ]; then
    echo "ERROR: missing $label: $src" >&2
    exit 1
  fi
  cp "$src" "$dest"
}

copy_first_existing() {
  dest=$1
  label=$2
  shift 2

  for src in "$@"; do
    if [ -s "$src" ]; then
      cp "$src" "$dest"
      echo "Using $label: $src"
      return
    fi
  done

  echo "ERROR: missing $label. Tried:" >&2
  for src in "$@"; do
    echo "  $src" >&2
  done
  exit 1
}

link_file() {
  link_name=$1
  target_name=$2

  rm -f "$RUN_DIR/$link_name"
  ln -s "$target_name" "$RUN_DIR/$link_name"
}

mkdir -p "$RUN_DIR"

copy_required "$CG_RUN_DIR/Si111-H_sd.in" "$RUN_DIR/Si111-H_sd.in" "SD input"
copy_required "$CG_RUN_DIR/size.dat" "$RUN_DIR/size.dat" "mesh metadata"
copy_required "$CG_RUN_DIR/sym.C1" "$RUN_DIR/sym.C1" "symmetry metadata"
copy_required "$CG_RUN_DIR/TR.Si93g_asci" "$RUN_DIR/TR.Si93g_asci" "Si ground pseudopotential"
copy_required "$CG_RUN_DIR/TR.H99g_asc" "$RUN_DIR/TR.H99g_asc" "H pseudopotential"
copy_required "$CG_RUN_DIR/TR.Si93e_asci" "$RUN_DIR/TR.Si93e_asci" "Si excited pseudopotential"

if [ -f "$CG_RUN_DIR/Si111-H.in" ]; then
  cp "$CG_RUN_DIR/Si111-H.in" "$RUN_DIR/Si111-H.in"
fi

copy_first_existing "$RUN_DIR/rh.Si111-H" "CG density" \
  "$CG_RUN_DIR/rh.Si111-H_new" \
  "$CG_RUN_DIR/fort.24" \
  "$CG_RUN_DIR/rh.Si111-H"

copy_first_existing "$RUN_DIR/wf_fft.Si111-H" "CG reciprocal wavefunction" \
  "$CG_RUN_DIR/wf_fft.Si111-H_new" \
  "$CG_RUN_DIR/fort.23" \
  "$CG_RUN_DIR/wf_fft.Si111-H"

copy_first_existing "$RUN_DIR/wf_real.Si111-H" "CG real-space wavefunction" \
  "$CG_RUN_DIR/wf_real.Si111-H" \
  "$CG_RUN_DIR/fort.88"

link_file fort.20 rh.Si111-H
link_file fort.22 wf_fft.Si111-H
link_file fort.41 TR.Si93g_asci
link_file fort.42 TR.H99g_asc
link_file fort.46 TR.Si93e_asci
link_file fort.54 size.dat
link_file fort.55 sym.C1
link_file fort.88 wf_real.Si111-H

cat > "$RUN_DIR/run.sd.sh" <<EOF
#!/bin/sh
set -eu

ulimit -s unlimited 2>/dev/null || true
export OMP_NUM_THREADS=\${OMP_NUM_THREADS:-1}
export OMP_STACKSIZE=\${OMP_STACKSIZE:-512M}

rm -f fort.23 fort.24 fort.90 rh.Si111-H_new wf_fft.Si111-H_new
"$SD_EXE" < Si111-H_sd.in > Si111-H_sd.out 2> Si111-H_sd.err

if [ -f fort.24 ]; then
  cp fort.24 rh.Si111-H_new
fi
if [ -f fort.23 ]; then
  cp fort.23 wf_fft.Si111-H_new
fi
if [ -f fort.88 ]; then
  cp fort.88 wf_real.Si111-H
fi
EOF
chmod +x "$RUN_DIR/run.sd.sh"

echo "Prepared SD run directory:"
echo "  $RUN_DIR"
echo
echo "Run SD:"
echo "  cd $RUN_DIR"
echo "  ./run.sd.sh"
echo
echo "Check result:"
echo "  $ROOT_DIR/tools/check_sd_result.sh $RUN_DIR"
