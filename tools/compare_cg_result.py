#!/usr/bin/env python3
"""Compare FPSEID21 CG output logs across platforms.

The comparison focuses on numeric observables from stdout. Generated state files
can also be reported by size and SHA-256, but exact byte equality is not required
by default because compilers and reduction orders may change low bits while the
physical result remains acceptable.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


FLOAT_RE = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[dDeE][-+]?\d+)?"
BAD_RE = re.compile(
    r"NaN|Infinity|SIGSEGV|segmentation|fatal|traceback|cannot|failed|invalid|BADFMT",
    re.IGNORECASE,
)


@dataclass
class CgResult:
    path: Path
    etot: float | None
    total_charge: float | None
    forces: list[tuple[int, float, float, float]]
    bands: list[tuple[int, int, float]]
    completed: bool
    bad_lines: list[str]


def parse_float(text: str) -> float:
    return float(text.replace("D", "E").replace("d", "E"))


def parse_cg_output(path: Path, err_paths: Iterable[Path] = ()) -> CgResult:
    etot: float | None = None
    total_charge: float | None = None
    forces: list[tuple[int, float, float, float]] = []
    bands: list[tuple[int, int, float]] = []
    bad_lines: list[str] = []
    completed = False
    current_k = 0
    in_force = False

    if not path.is_file():
        raise FileNotFoundError(path)

    with path.open(errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if BAD_RE.search(line):
                bad_lines.append(line)
            if "CPU TIME END OF PSPW" in line:
                completed = True
            if "TOTAL ENERGY: ETOT" in line:
                match = re.search(r"ETOT\s*=\s*(%s)" % FLOAT_RE, line)
                if match:
                    etot = parse_float(match.group(1))
            if "TOTAL CHARGE" in line:
                nums = re.findall(FLOAT_RE, line)
                if nums:
                    total_charge = parse_float(nums[-1])
            if line.lstrip().startswith("K VECTOR"):
                nums = re.findall(r"[-+]?\d+", line)
                if nums:
                    current_k = int(nums[0])
            if "BAND (EV)" in line:
                nums = re.findall(FLOAT_RE, line)
                if len(nums) >= 2:
                    bands.append((current_k, int(parse_float(nums[0])), parse_float(nums[1])))
            if "TOTAL FORCE:" in line:
                in_force = True
                continue
            if in_force:
                parts = line.split()
                if len(parts) >= 4 and re.fullmatch(r"[-+]?\d+", parts[0]):
                    try:
                        forces.append(
                            (
                                int(parts[0]),
                                parse_float(parts[1]),
                                parse_float(parts[2]),
                                parse_float(parts[3]),
                            )
                        )
                    except ValueError:
                        bad_lines.append(line)
                    continue
                if forces and not parts:
                    in_force = False

    for err_path in err_paths:
        if not err_path.is_file() or err_path.stat().st_size == 0:
            continue
        with err_path.open(errors="replace") as fh:
            for raw in fh:
                line = raw.rstrip("\n")
                if BAD_RE.search(line):
                    bad_lines.append(f"{err_path}: {line}")

    return CgResult(path, etot, total_charge, forces, bands, completed, bad_lines)


def finite(value: float | None) -> bool:
    return value is not None and math.isfinite(value)


def max_abs_diff(ref_values: list[float], test_values: list[float]) -> float | None:
    if len(ref_values) != len(test_values):
        return None
    if not ref_values:
        return 0.0
    return max(abs(a - b) for a, b in zip(ref_values, test_values))


def flatten_forces(result: CgResult) -> list[float]:
    values: list[float] = []
    for _atom, fx, fy, fz in result.forces:
        values.extend([fx, fy, fz])
    return values


def band_values(result: CgResult) -> list[float]:
    return [energy for _k, _band, energy in result.bands]


def print_check(result: CgResult) -> list[str]:
    failures: list[str] = []
    print(f"file: {result.path}")
    print(f"  completed: {result.completed}")
    print(f"  ETOT(HR): {result.etot}")
    print(f"  total_charge: {result.total_charge}")
    print(f"  forces: {len(result.forces)} atoms")
    print(f"  band energies: {len(result.bands)}")
    print(f"  suspicious lines: {len(result.bad_lines)}")

    if not result.completed:
        failures.append("missing CPU TIME END OF PSPW marker")
    if not finite(result.etot):
        failures.append("missing or non-finite ETOT")
    if not result.forces:
        failures.append("missing force block")
    if result.bad_lines:
        failures.append(f"found suspicious log lines: {len(result.bad_lines)}")

    return failures


def compare_scalar(label: str, ref: float | None, test: float | None, tol: float) -> list[str]:
    if not finite(ref) or not finite(test):
        print(f"{label}: missing value FAIL")
        return [f"{label}: missing value"]
    diff = abs(float(ref) - float(test))
    status = "OK" if diff <= tol else "FAIL"
    print(f"{label}: abs_diff={diff:.6e} tolerance={tol:.6e} {status}")
    if status == "FAIL":
        return [f"{label}: diff {diff:.6e} exceeds tolerance {tol:.6e}"]
    return []


def compare_vector(label: str, ref: list[float], test: list[float], tol: float) -> list[str]:
    diff = max_abs_diff(ref, test)
    if diff is None:
        print(f"{label}: length mismatch ref={len(ref)} test={len(test)} FAIL")
        return [f"{label}: length mismatch ref={len(ref)} test={len(test)}"]
    status = "OK" if diff <= tol else "FAIL"
    print(f"{label}: max_abs_diff={diff:.6e} tolerance={tol:.6e} {status}")
    if status == "FAIL":
        return [f"{label}: diff {diff:.6e} exceeds tolerance {tol:.6e}"]
    return []


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def first_existing(run_dir: Path, names: Iterable[str]) -> Path | None:
    for name in names:
        path = run_dir / name
        if path.exists():
            return path
    return None


def compare_state_files(ref_dir: Path, test_dir: Path, require_match: bool) -> list[str]:
    failures: list[str] = []
    groups = [
        ("density", ["rh.Si111-H_new", "rh.Si111-H", "fort.24"]),
        ("wavefunction", ["wf_fft.Si111-H_new", "wf_fft.Si111-H", "fort.23"]),
        ("real-space wavefunction", ["wf_real.Si111-H", "fort.88"]),
    ]
    print()
    print("CG state files")
    for label, names in groups:
        ref = first_existing(ref_dir, names)
        test = first_existing(test_dir, names)
        if ref is None or test is None:
            print(f"{label}: missing ref={ref} test={test}")
            if require_match:
                failures.append(f"{label}: missing state file")
            continue
        ref_hash = sha256(ref)
        test_hash = sha256(test)
        same = ref_hash == test_hash and ref.stat().st_size == test.stat().st_size
        status = "MATCH" if same else "DIFF"
        print(
            f"{label}: {status} "
            f"ref_size={ref.stat().st_size} test_size={test.stat().st_size} "
            f"ref_sha256={ref_hash} test_sha256={test_hash}"
        )
        if require_match and not same:
            failures.append(f"{label}: file hash/size differs")
    return failures


def command_check(args: argparse.Namespace) -> int:
    result = parse_cg_output(args.output, args.err)
    failures = print_check(result)
    if failures:
        print()
        print("FAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print()
    print("PASS")
    return 0


def command_compare(args: argparse.Namespace) -> int:
    ref = parse_cg_output(args.reference, args.ref_err)
    test = parse_cg_output(args.test, args.test_err)

    failures: list[str] = []
    failures.extend(f"reference: {msg}" for msg in print_check(ref))
    failures.extend(f"test: {msg}" for msg in print_check(test))

    print()
    print("CG comparison")
    print(f"  reference: {args.reference}")
    print(f"  test:      {args.test}")
    failures.extend(compare_scalar("ETOT", ref.etot, test.etot, args.etot_tol))
    failures.extend(compare_scalar("total_charge", ref.total_charge, test.total_charge, args.charge_tol))
    failures.extend(compare_vector("force", flatten_forces(ref), flatten_forces(test), args.force_tol))
    failures.extend(compare_vector("band_energy", band_values(ref), band_values(test), args.band_tol))

    if args.ref_run_dir and args.test_run_dir:
        failures.extend(
            compare_state_files(args.ref_run_dir, args.test_run_dir, args.require_file_match)
        )

    if failures:
        print()
        print("FAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print()
    print("PASS")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Check and compare FPSEID21 CG output logs across platforms. "
            "Run compare_cg_run_inputs.sh first; large ETOT/force differences "
            "usually mean the CG inputs are not identical."
        )
    )
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check", help="sanity-check one CG output log")
    check.add_argument("output", type=Path)
    check.add_argument("--err", type=Path, action="append", default=[])
    check.set_defaults(func=command_check)

    compare = sub.add_parser("compare", help="compare two CG output logs")
    compare.add_argument("reference", type=Path)
    compare.add_argument("test", type=Path)
    compare.add_argument("--ref-err", type=Path, action="append", default=[])
    compare.add_argument("--test-err", type=Path, action="append", default=[])
    compare.add_argument("--etot-tol", type=float, default=1.0e-6)
    compare.add_argument("--charge-tol", type=float, default=1.0e-6)
    compare.add_argument("--force-tol", type=float, default=1.0e-5)
    compare.add_argument("--band-tol", type=float, default=1.0e-4)
    compare.add_argument("--ref-run-dir", type=Path)
    compare.add_argument("--test-run-dir", type=Path)
    compare.add_argument(
        "--require-file-match",
        action="store_true",
        help="fail if generated state files differ byte-for-byte",
    )
    compare.set_defaults(func=command_compare)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
