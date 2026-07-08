#!/usr/bin/env python3
"""Compare FPSEID21 SD output logs across platforms.

By default this compares a test SD log against the committed GNU reference log:

  docs/runtime_logs/gnu_si111_h_sd.out

The parser is shared with the CG comparison tool because SD and CG print the
same ETOT, SCF convergence, force, and band-energy sections.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from compare_cg_result import (
    band_values,
    compare_convergence,
    compare_scalar,
    compare_vector,
    finite,
    first_existing,
    flatten_forces,
    parse_cg_output,
    print_check,
    sha256,
)


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
DEFAULT_REFERENCE = ROOT_DIR / "docs/runtime_logs/gnu_si111_h_sd.out"
DEFAULT_REFERENCE_ERR = ROOT_DIR / "docs/runtime_logs/gnu_si111_h_sd.err"


def compare_state_files(ref_dir: Path, test_dir: Path, require_match: bool) -> list[str]:
    failures: list[str] = []
    groups = [
        ("density unit", ["fort.24"]),
        ("density promoted", ["rh.Si111-H_new", "rh.Si111-H"]),
        ("reciprocal wavefunction unit", ["fort.23"]),
        ("reciprocal wavefunction promoted", ["wf_fft.Si111-H_new", "wf_fft.Si111-H"]),
        ("real-space wavefunction unit", ["fort.88"]),
        ("real-space wavefunction promoted", ["wf_real.Si111-H"]),
    ]
    print()
    print("SD state files")
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
    ref_err = list(args.ref_err)
    if args.reference == DEFAULT_REFERENCE and DEFAULT_REFERENCE_ERR.is_file():
        ref_err.append(DEFAULT_REFERENCE_ERR)

    ref = parse_cg_output(args.reference, ref_err)
    test = parse_cg_output(args.test, args.test_err)

    failures: list[str] = []
    failures.extend(f"reference: {msg}" for msg in print_check(ref))
    failures.extend(f"test: {msg}" for msg in print_check(test))

    print()
    print("SD comparison")
    print(f"  reference: {args.reference}")
    print(f"  test:      {args.test}")
    failures.extend(compare_scalar("ETOT", ref.etot, test.etot, args.etot_tol))
    if finite(ref.total_charge) or finite(test.total_charge):
        failures.extend(
            compare_scalar("total_charge", ref.total_charge, test.total_charge, args.charge_tol)
        )
    else:
        print("total_charge: unavailable in both logs SKIP")
    failures.extend(compare_convergence(ref, test, args.convergence_tol))
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
            "Check and compare FPSEID21 SD output logs across platforms. "
            "The compare command uses docs/runtime_logs/gnu_si111_h_sd.out "
            "as the default reference."
        )
    )
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check", help="sanity-check one SD output log")
    check.add_argument("output", type=Path)
    check.add_argument("--err", type=Path, action="append", default=[])
    check.set_defaults(func=command_check)

    compare = sub.add_parser("compare", help="compare a test SD log to a reference")
    compare.add_argument("test", type=Path)
    compare.add_argument("--reference", type=Path, default=DEFAULT_REFERENCE)
    compare.add_argument("--ref-err", type=Path, action="append", default=[])
    compare.add_argument("--test-err", type=Path, action="append", default=[])
    compare.add_argument("--etot-tol", type=float, default=1.0e-6)
    compare.add_argument("--charge-tol", type=float, default=1.0e-6)
    compare.add_argument("--convergence-tol", type=float, default=1.0e-8)
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
