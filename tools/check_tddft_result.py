#!/usr/bin/env python3
"""Check and compare FPSEID21 TDDFT output logs.

The checker intentionally compares numeric observables with tolerances instead
of requiring bitwise equality. Different compilers, MPI implementations, and
rank counts can change reduction order while still producing an acceptable
physical result.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


FLOAT = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[DEde][-+]?\d+)?"
BAD_PATTERN = re.compile(
    r"\b(error|incorrect|nan|inf|abort|sigsegv|severe|invalid)\b",
    re.IGNORECASE,
)
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
DEFAULT_REFERENCE = ROOT_DIR / "docs/runtime_logs/gnu_si111_h_tddft_100steps.out"
DEFAULT_REFERENCE_ERR = ROOT_DIR / "docs/runtime_logs/gnu_si111_h_tddft_100steps.err"
RELAXED_TOLERANCES = {
    "energy": 1.0e-4,
    "force": 1.0e-4,
    "position": 1.0e-6,
    "velocity": 1.0e-6,
}
STRICT_TOLERANCES = {
    "energy": 1.0e-5,
    "force": 1.0e-5,
    "position": 1.0e-6,
    "velocity": 1.0e-6,
}


def to_float(text: str) -> float:
    return float(text.replace("D", "E").replace("d", "e"))


def positive_int(text: str) -> int:
    value = int(text)
    if value <= 0:
        raise argparse.ArgumentTypeError("expected a positive integer")
    return value


def read_text(path: Path) -> str:
    return path.read_text(errors="replace")


@dataclass
class TddftResult:
    path: Path
    etot: float | None
    energy_total: float | None
    steps: int | None
    steps_sec: float | None
    force: list[tuple[int, tuple[float, float, float]]]
    positions: list[tuple[int, tuple[float, float, float]]]
    velocities: list[tuple[int, tuple[float, float, float]]]
    profile: dict[str, tuple[int, float, float]]
    bad_lines: list[str]


def last_float_after(pattern: str, text: str) -> float | None:
    matches = re.findall(pattern, text, re.MULTILINE)
    if not matches:
        return None
    value = matches[-1]
    if isinstance(value, tuple):
        value = value[-1]
    return to_float(value)


def parse_force_blocks(lines: list[str]) -> list[tuple[int, tuple[float, float, float]]]:
    blocks: list[list[tuple[int, tuple[float, float, float]]]] = []
    current: list[tuple[int, tuple[float, float, float]]] | None = None
    row_re = re.compile(rf"^\s*(\d+)\s+({FLOAT})\s+({FLOAT})\s+({FLOAT})\s*$")

    for line in lines:
        if "TOTAL FORCE: NEGATIVE" in line:
            current = []
            blocks.append(current)
            continue
        if current is None:
            continue
        match = row_re.match(line)
        if match:
            current.append(
                (
                    int(match.group(1)),
                    (to_float(match.group(2)), to_float(match.group(3)), to_float(match.group(4))),
                )
            )
        elif current:
            current = None

    return blocks[-1] if blocks else []


def parse_tau_section(lines: list[str], header: str) -> list[tuple[int, tuple[float, float, float]]]:
    sections: list[list[tuple[int, tuple[float, float, float]]]] = []
    current: list[tuple[int, tuple[float, float, float]]] | None = None
    row_re = re.compile(rf"^\s*({FLOAT})\s+({FLOAT})\s+({FLOAT})\s+TAU\(\s*(\d+)\)")

    for line in lines:
        if line.strip() == header:
            current = []
            sections.append(current)
            continue
        if current is None:
            continue
        match = row_re.match(line)
        if match:
            current.append(
                (
                    int(match.group(4)),
                    (to_float(match.group(1)), to_float(match.group(2)), to_float(match.group(3))),
                )
            )
        elif current:
            current = None

    return sections[-1] if sections else []


def parse_profile(lines: list[str]) -> dict[str, tuple[int, float, float]]:
    blocks: list[dict[str, tuple[int, float, float]]] = []
    current: dict[str, tuple[int, float, float]] | None = None
    row_re = re.compile(rf"^\s*\d+\s+([A-Za-z0-9_]+)\s+(\d+)\s+({FLOAT})\s+({FLOAT})\s*$")

    for line in lines:
        if "FPSEID_PROFILE_BEGIN" in line:
            current = {}
            blocks.append(current)
            continue
        if "FPSEID_PROFILE_END" in line:
            current = None
            continue
        if current is None:
            continue
        match = row_re.match(line)
        if match:
            current[match.group(1)] = (
                int(match.group(2)),
                to_float(match.group(3)),
                to_float(match.group(4)),
            )

    return blocks[-1] if blocks else {}


def parse_result(path: Path, error_paths: Iterable[Path] = ()) -> TddftResult:
    text = read_text(path)
    lines = text.splitlines()
    extra_error_text = "\n".join(read_text(error_path) for error_path in error_paths)
    bad_lines = [
        line
        for line in (text + "\n" + extra_error_text).splitlines()
        if BAD_PATTERN.search(line)
    ]

    step_match = re.findall(rf"^\s*(\d+)\s+steps took\s+({FLOAT})\s+sec", text, re.MULTILINE)
    steps = int(step_match[-1][0]) if step_match else None
    steps_sec = to_float(step_match[-1][1]) if step_match else None

    return TddftResult(
        path=path,
        etot=last_float_after(rf"TOTAL ENERGY:\s+ETOT\s+=\s+({FLOAT})", text),
        energy_total=last_float_after(rf"Eelec\+Enucl-Eext-Ework=\s+({FLOAT})", text),
        steps=steps,
        steps_sec=steps_sec,
        force=parse_force_blocks(lines),
        positions=parse_tau_section(lines, "Positions"),
        velocities=parse_tau_section(lines, "Velocities"),
        profile=parse_profile(lines),
        bad_lines=bad_lines,
    )


def max_vector_diff(
    ref: list[tuple[int, tuple[float, float, float]]],
    test: list[tuple[int, tuple[float, float, float]]],
) -> tuple[float | None, str]:
    if not ref or not test:
        return None, "missing vector block"
    ref_map = dict(ref)
    test_map = dict(test)
    if set(ref_map) != set(test_map):
        missing_ref = sorted(set(ref_map) - set(test_map))
        missing_test = sorted(set(test_map) - set(ref_map))
        return None, f"different ids: missing_in_test={missing_ref} missing_in_ref={missing_test}"

    max_diff = -1.0
    max_label = ""
    for idx in sorted(ref_map):
        for comp, (a, b) in enumerate(zip(ref_map[idx], test_map[idx]), start=1):
            diff = abs(a - b)
            if diff > max_diff:
                max_diff = diff
                max_label = f"id={idx} component={comp} ref={a:.16e} test={b:.16e}"
    return max_diff, max_label


def finite_or_none(value: float | None) -> bool:
    return value is not None and math.isfinite(value)


def check_result(
    result: TddftResult,
    require_profile: bool,
    expected_steps: int | None,
    expected_atoms: int | None = None,
) -> list[str]:
    failures: list[str] = []
    if result.bad_lines:
        failures.append(f"found suspicious log lines: {len(result.bad_lines)}")
    if result.steps is None:
        failures.append("missing 'steps took' completion marker")
    elif expected_steps is not None and result.steps != expected_steps:
        failures.append(f"expected {expected_steps} completed steps, found {result.steps}")
    if not finite_or_none(result.steps_sec) or result.steps_sec <= 0.0:
        failures.append("missing, non-finite, or non-positive step wall time")
    if not finite_or_none(result.etot):
        failures.append("missing or non-finite TOTAL ENERGY: ETOT")
    if not finite_or_none(result.energy_total):
        failures.append("missing or non-finite Eelec+Enucl-Eext-Ework")
    if not result.force:
        failures.append("missing final TOTAL FORCE block")
    if not result.positions:
        failures.append("missing final Positions block")
    if expected_atoms is not None:
        for name, rows in (
            ("force", result.force),
            ("positions", result.positions),
            ("velocities", result.velocities),
        ):
            if len(rows) != expected_atoms:
                failures.append(
                    f"expected {expected_atoms} {name} rows, found {len(rows)}"
                )
    if require_profile and not result.profile:
        failures.append("missing FPSEID_PROFILE block")
    return failures


def print_summary(result: TddftResult) -> None:
    print(f"file: {result.path}")
    print(f"  ETOT: {result.etot}")
    print(f"  Eelec+Enucl-Eext-Ework: {result.energy_total}")
    if result.steps is not None:
        print(f"  steps: {result.steps}, wall_sec: {result.steps_sec}")
    print(f"  forces: {len(result.force)} atoms")
    print(f"  positions: {len(result.positions)} atoms")
    print(f"  velocities: {len(result.velocities)} atoms")
    print(f"  profile timers: {len(result.profile)}")
    if result.bad_lines:
        print("  suspicious lines:")
        for line in result.bad_lines[:10]:
            print(f"    {line}")
        if len(result.bad_lines) > 10:
            print(f"    ... {len(result.bad_lines) - 10} more")


def compare(args: argparse.Namespace) -> int:
    if len(args.paths) == 1:
        reference = args.reference
        test_path = args.paths[0]
    elif len(args.paths) == 2:
        reference = args.paths[0]
        test_path = args.paths[1]
    else:
        raise SystemExit("compare expects TEST, or REFERENCE TEST")

    ref_err = list(args.ref_err)
    if reference == DEFAULT_REFERENCE and DEFAULT_REFERENCE_ERR.is_file():
        ref_err.append(DEFAULT_REFERENCE_ERR)

    ref = parse_result(reference, ref_err)
    test = parse_result(test_path, args.test_err)
    tolerances = STRICT_TOLERANCES if args.strict else {
        "energy": args.energy_atol,
        "force": args.force_atol,
        "position": args.position_atol,
        "velocity": args.velocity_atol,
    }

    failures = []
    failures.extend(
        f"reference: {msg}"
        for msg in check_result(
            ref, args.require_profile, args.expected_steps, args.expected_atoms
        )
    )
    failures.extend(
        f"test: {msg}"
        for msg in check_result(
            test, args.require_profile, args.expected_steps, args.expected_atoms
        )
    )
    if ref.steps is not None and test.steps is not None and ref.steps != test.steps:
        failures.append(f"steps: reference={ref.steps} test={test.steps}")

    comparisons: list[tuple[str, float | None, float, str]] = []
    if finite_or_none(ref.etot) and finite_or_none(test.etot):
        comparisons.append(("ETOT", abs(ref.etot - test.etot), tolerances["energy"], ""))
    if finite_or_none(ref.energy_total) and finite_or_none(test.energy_total):
        comparisons.append(
            (
                "Eelec+Enucl-Eext-Ework",
                abs(ref.energy_total - test.energy_total),
                tolerances["energy"],
                "",
            )
        )

    force_diff, force_detail = max_vector_diff(ref.force, test.force)
    comparisons.append(("force", force_diff, tolerances["force"], force_detail))
    pos_diff, pos_detail = max_vector_diff(ref.positions, test.positions)
    comparisons.append(("positions", pos_diff, tolerances["position"], pos_detail))
    if ref.velocities and test.velocities:
        vel_diff, vel_detail = max_vector_diff(ref.velocities, test.velocities)
        comparisons.append(("velocities", vel_diff, tolerances["velocity"], vel_detail))

    print("TDDFT comparison")
    print(f"  reference: {ref.path}")
    print(f"  test:      {test.path}")
    if args.strict:
        print("  tolerance mode: strict")
    else:
        print("  tolerance mode: relaxed")
    if ref.steps is not None and test.steps is not None:
        status = "OK" if ref.steps == test.steps else "FAIL"
        print(f"  steps: reference={ref.steps} test={test.steps} {status}")
    for name, diff, tol, detail in comparisons:
        if diff is None:
            failures.append(f"{name}: {detail}")
            print(f"  {name}: unavailable ({detail})")
            continue
        status = "OK" if diff <= tol else "FAIL"
        detail_text = f" ({detail})" if detail else ""
        print(f"  {name}: max_abs_diff={diff:.6e} tolerance={tol:.6e} {status}{detail_text}")
        if diff > tol:
            failures.append(f"{name}: diff {diff:.6e} exceeds tolerance {tol:.6e}{detail_text}")

    if failures:
        print("\nFAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("\nPASS")
    return 0


def check(args: argparse.Namespace) -> int:
    result = parse_result(args.output, args.err)
    failures = check_result(
        result, args.require_profile, args.expected_steps, args.expected_atoms
    )
    print_summary(result)
    if failures:
        print("\nFAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("\nPASS")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    check_parser = sub.add_parser("check", help="sanity-check one TDDFT output log")
    check_parser.add_argument("output", type=Path)
    check_parser.add_argument("--err", type=Path, action="append", default=[])
    check_parser.add_argument(
        "--expected-steps",
        type=positive_int,
        help="require the completion marker to report exactly this many steps",
    )
    check_parser.add_argument(
        "--expected-atoms",
        type=positive_int,
        help="require exactly this many force, position, and velocity rows",
    )
    check_parser.add_argument("--require-profile", action=argparse.BooleanOptionalAction, default=True)
    check_parser.set_defaults(func=check)

    compare_parser = sub.add_parser("compare", help="compare TDDFT output logs")
    compare_parser.add_argument(
        "paths",
        type=Path,
        nargs="+",
        help="TEST, or REFERENCE TEST for the legacy calling form",
    )
    compare_parser.add_argument("--reference", type=Path, default=DEFAULT_REFERENCE)
    compare_parser.add_argument("--ref-err", type=Path, action="append", default=[])
    compare_parser.add_argument("--test-err", type=Path, action="append", default=[])
    compare_parser.add_argument(
        "--expected-steps",
        type=positive_int,
        help="require both completion markers to report exactly this many steps",
    )
    compare_parser.add_argument(
        "--expected-atoms",
        type=positive_int,
        help="require exactly this many force, position, and velocity rows in both logs",
    )
    compare_parser.add_argument("--energy-atol", type=float, default=RELAXED_TOLERANCES["energy"])
    compare_parser.add_argument("--force-atol", type=float, default=RELAXED_TOLERANCES["force"])
    compare_parser.add_argument("--position-atol", type=float, default=RELAXED_TOLERANCES["position"])
    compare_parser.add_argument("--velocity-atol", type=float, default=RELAXED_TOLERANCES["velocity"])
    compare_parser.add_argument(
        "--strict",
        action="store_true",
        help="use strict tolerances: energy=1e-5 force=1e-5 position=1e-6 velocity=1e-6",
    )
    compare_parser.add_argument("--require-profile", action=argparse.BooleanOptionalAction, default=True)
    compare_parser.set_defaults(func=compare)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
