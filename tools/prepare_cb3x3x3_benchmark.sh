#!/bin/sh
set -eu

# Download and stage the official FPSEID21 diamond cb3x3x3 benchmark without
# mixing it with the historical Si111-H run directories or archives.
#
# Optional environment:
#   BENCHMARK_ROOT  default: <repo>/run/benchmarks/cb3x3x3
#   ZIP_PATH        use an already-downloaded official ZIP
#   PSEUDO_PATH     use an already-downloaded TR.C95g_asci

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
DOWNLOAD_DIR=$BENCHMARK_ROOT/downloads
OFFICIAL_DIR=$BENCHMARK_ROOT/official
WORK_ROOT=$BENCHMARK_ROOT/work
ARCHIVE_ROOT=$BENCHMARK_ROOT/archives

PACKAGE_URL=https://staff.aist.go.jp/yoshi-miyamoto/ja/download/benchmark-cb3x3x3.zip
PACKAGE_SHA256=793a7754a416c83f00f563a7de3ce49d570f6830db89388d2e3b7b808c2612f9
PSEUDO_URL=https://staff.aist.go.jp/yoshi-miyamoto/en/TR/TR.C95g_asci
PSEUDO_SHA256=bc743cb0f8829a2b07c68e1a33ce9a4c44c8cf75cc6503da3707fc9db90a5244

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_sha256() {
  path=$1
  expected=$2
  actual=$(sha256_file "$path")
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: SHA-256 mismatch: $path" >&2
    echo "  expected=$expected" >&2
    echo "  actual=$actual" >&2
    exit 1
  fi
}

copy_once() {
  src=$1
  dst=$2
  label=$3
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      return 0
    fi
    echo "ERROR: existing $label differs; refusing to overwrite: $dst" >&2
    exit 1
  fi
  cp -p "$src" "$dst"
}

link_once() {
  target=$1
  dst=$2
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$target" ]; then
      return 0
    fi
    echo "ERROR: existing link has a different target: $dst" >&2
    exit 1
  fi
  if [ -e "$dst" ]; then
    echo "ERROR: existing path blocks required link: $dst" >&2
    exit 1
  fi
  ln -s "$target" "$dst"
}

download_or_copy() {
  supplied=$1
  url=$2
  dst=$3
  expected=$4
  label=$5

  if [ -f "$dst" ]; then
    verify_sha256 "$dst" "$expected"
    return 0
  fi

  part=$dst.part
  if [ -e "$part" ]; then
    echo "ERROR: stale partial $label download exists: $part" >&2
    exit 1
  fi
  if [ -n "$supplied" ]; then
    if [ ! -f "$supplied" ]; then
      echo "ERROR: supplied $label does not exist: $supplied" >&2
      exit 1
    fi
    cp -p "$supplied" "$part"
  else
    curl -fL "$url" -o "$part"
  fi
  verify_sha256 "$part" "$expected"
  mv "$part" "$dst"
}

mkdir -p "$DOWNLOAD_DIR" "$WORK_ROOT" "$ARCHIVE_ROOT"

package_zip=$DOWNLOAD_DIR/benchmark-cb3x3x3.zip
carbon_pseudo=$DOWNLOAD_DIR/TR.C95g_asci
download_or_copy "${ZIP_PATH:-}" "$PACKAGE_URL" "$package_zip" \
  "$PACKAGE_SHA256" "benchmark package"
download_or_copy "${PSEUDO_PATH:-}" "$PSEUDO_URL" "$carbon_pseudo" \
  "$PSEUDO_SHA256" "carbon pseudopotential"

if [ ! -d "$OFFICIAL_DIR" ]; then
  staging=$(mktemp -d "$BENCHMARK_ROOT/.official.XXXXXX")
  trap 'rm -rf "$staging"' EXIT HUP INT TERM

  if unzip -Z1 "$package_zip" | awk '
      /^\// || /(^|\/)\.\.($|\/)/ { bad=1 }
      END { exit bad ? 0 : 1 }
    '; then
    echo "ERROR: unsafe path found in official ZIP" >&2
    exit 1
  fi

  mkdir -p "$staging/unpack"
  unzip -q "$package_zip" -d "$staging/unpack"
  source_dir=$staging/unpack/benchmark-cb3x3x3
  for rel in \
    'Read me.docx' dia-cb3x3x3.in dia-cb3x3x3_sd.in \
    dia-cb3x3x3_tm.in_begin size.dat 'sym,C1' \
    600K/dia-cb3x3x3_tm.in 600K/dia-cb3x3x3_tm.out_AOBA-S \
    600K/size.dat 600K/sym.C1 600K/laser.dat
  do
    if [ ! -f "$source_dir/$rel" ]; then
      echo "ERROR: official package is missing: $rel" >&2
      exit 1
    fi
  done

  mkdir -p "$source_dir/TR"
  cp -p "$carbon_pseudo" "$source_dir/TR/TR.C95g_asci"
  {
    echo "official_update=2026-08-08"
    echo "package_url=$PACKAGE_URL"
    echo "package_sha256=$PACKAGE_SHA256"
    echo "pseudopotential_url=$PSEUDO_URL"
    echo "pseudopotential_sha256=$PSEUDO_SHA256"
    echo "case=diamond_cb3x3x3"
    echo "atoms=216"
    echo "mesh=105x105x105"
    echo "cg_sd_bands=576"
    echo "tddft_bands=480"
    echo "official_steps=40000"
  } > "$source_dir/SOURCE_MANIFEST.env"
  mv "$source_dir" "$OFFICIAL_DIR"
  trap - EXIT HUP INT TERM
  rm -rf "$staging"
fi

verify_sha256 "$OFFICIAL_DIR/TR/TR.C95g_asci" "$PSEUDO_SHA256"

for stage in cg sd tddft_600K; do
  mkdir -p "$WORK_ROOT/$stage"
done

for stage in cg sd; do
  copy_once "$OFFICIAL_DIR/600K/laser.dat" "$WORK_ROOT/$stage/laser.dat" laser.dat
  for zero in Eext Etot Avec Ework; do
    copy_once "$OFFICIAL_DIR/600K/$zero" "$WORK_ROOT/$stage/$zero" "$zero"
  done
  copy_once "$OFFICIAL_DIR/TR/TR.C95g_asci" \
    "$WORK_ROOT/$stage/TR.C95g_asci" TR.C95g_asci
  copy_once "$OFFICIAL_DIR/size.dat" "$WORK_ROOT/$stage/size.dat" size.dat
  copy_once "$OFFICIAL_DIR/sym,C1" "$WORK_ROOT/$stage/sym.C1" sym.C1
  link_once TR.C95g_asci "$WORK_ROOT/$stage/fort.41"
  link_once laser.dat "$WORK_ROOT/$stage/fort.53"
  link_once size.dat "$WORK_ROOT/$stage/fort.54"
  link_once sym.C1 "$WORK_ROOT/$stage/fort.55"
done

copy_once "$OFFICIAL_DIR/dia-cb3x3x3.in" \
  "$WORK_ROOT/cg/dia-cb3x3x3.in" "CG input"
copy_once "$OFFICIAL_DIR/dia-cb3x3x3_sd.in" \
  "$WORK_ROOT/sd/dia-cb3x3x3_sd.in" "SD input"

tddft_dir=$WORK_ROOT/tddft_600K
for rel in Avec Cartesian.velo Eext Etot Ework laser.dat size.dat sym.C1; do
  copy_once "$OFFICIAL_DIR/600K/$rel" "$tddft_dir/$rel" "$rel"
done
copy_once "$OFFICIAL_DIR/600K/dia-cb3x3x3_tm.in" \
  "$tddft_dir/dia-cb3x3x3_tm.in_40000steps" "official TDDFT input"
copy_once "$OFFICIAL_DIR/TR/TR.C95g_asci" "$tddft_dir/TR.C95g_asci" TR.C95g_asci
copy_once "$OFFICIAL_DIR/SOURCE_MANIFEST.env" \
  "$tddft_dir/SOURCE_MANIFEST.env" SOURCE_MANIFEST.env
link_once ../../official/600K/dia-cb3x3x3_tm.out_AOBA-S \
  "$tddft_dir/official_reference_40000steps.out"

for steps in 2 1000; do
  derived=$tddft_dir/dia-cb3x3x3_tm.in_${steps}steps
  if [ ! -e "$derived" ]; then
    sed "s/tstep=40000/tstep=$steps/" \
      "$OFFICIAL_DIR/600K/dia-cb3x3x3_tm.in" > "$derived"
  elif ! grep -Eq "tstep=$steps([[:space:]]|$)" "$derived"; then
    echo "ERROR: existing derived input has the wrong step count: $derived" >&2
    exit 1
  fi
done

link_once TR.C95g_asci "$tddft_dir/fort.41"
link_once Eext "$tddft_dir/fort.18"
link_once Etot "$tddft_dir/fort.28"
link_once laser.dat "$tddft_dir/fort.53"
link_once size.dat "$tddft_dir/fort.54"
link_once sym.C1 "$tddft_dir/fort.55"
link_once Avec "$tddft_dir/fort.60"
link_once Ework "$tddft_dir/fort.62"

copy_once "$OFFICIAL_DIR/SOURCE_MANIFEST.env" \
  "$BENCHMARK_ROOT/SOURCE_MANIFEST.env" SOURCE_MANIFEST.env

echo "Prepared official FPSEID21 cb3x3x3 benchmark:"
echo "  root:       $BENCHMARK_ROOT"
echo "  official:   $OFFICIAL_DIR"
echo "  CG work:    $WORK_ROOT/cg"
echo "  SD work:    $WORK_ROOT/sd"
echo "  TDDFT work: $tddft_dir"
echo "  archives:   $ARCHIVE_ROOT"
echo
echo "Initial rh/wf_fft state is not included in the official package."
echo "CG and SD must complete before TDDFT execution is authorized."
echo "Run the read-only preflight:"
echo "  ./tools/check_cb3x3x3_benchmark.sh"
