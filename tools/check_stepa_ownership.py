#!/usr/bin/env python3
"""Validate FPSEID Step A/B ownership diagnostics in a TDDFT log."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


RECORD_RE = re.compile(r"^(FPSEID_STEPA_[A-Z_]+)\s+(.*)$")
FIELD_RE = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=\s*(\S+)")


def parse_records(path: Path) -> dict[str, list[dict[str, str]]]:
    records: dict[str, list[dict[str, str]]] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = RECORD_RE.match(line.strip())
        if not match:
            continue
        kind, body = match.groups()
        records.setdefault(kind, []).append(dict(FIELD_RE.findall(body)))
    return records


def as_int(record: dict[str, str], field: str, failures: list[str], label: str) -> int | None:
    value = record.get(field)
    if value is None:
        failures.append(f"{label}: missing {field}")
        return None
    try:
        return int(value, 0)
    except ValueError:
        failures.append(f"{label}: invalid {field}={value}")
        return None


def one_per_phase(
    records: list[dict[str, str]], kind: str, failures: list[str]
) -> dict[int, dict[str, str]]:
    result: dict[int, dict[str, str]] = {}
    for record in records:
        phase = as_int(record, "phase", failures, kind)
        if phase is None:
            continue
        if phase in result:
            failures.append(f"{kind}: duplicate phase={phase}")
        else:
            result[phase] = record
    expected = set(range(1, 6))
    if set(result) != expected:
        failures.append(
            f"{kind}: expected phases 1-5, got {sorted(result)}"
        )
    return result


def validate_ylm(records: dict[str, list[dict[str, str]]]) -> list[str]:
    failures: list[str] = []
    parents = one_per_phase(
        records.get("FPSEID_STEPA_YLM_PARENT", []),
        "FPSEID_STEPA_YLM_PARENT",
        failures,
    )
    sections = one_per_phase(
        records.get("FPSEID_STEPA_YLM_SECTION", []),
        "FPSEID_STEPA_YLM_SECTION",
        failures,
    )

    for phase in sorted(set(parents) & set(sections)):
        parent = parents[phase]
        section = sections[phase]
        label = f"YLM phase={phase}"
        expected_symbol = f"YLM{phase}"

        for record_name, record in (("parent", parent), ("section", section)):
            if record.get("symbol") != expected_symbol:
                failures.append(
                    f"{label} {record_name}: expected symbol={expected_symbol}, "
                    f"got {record.get('symbol')}"
                )
            if record.get("query_status") != "OK":
                failures.append(
                    f"{label} {record_name}: query_status="
                    f"{record.get('query_status')}"
                )

        if as_int(parent, "parent_present", failures, label) != 1:
            failures.append(f"{label}: parent_present is not 1")
        if as_int(section, "section_present", failures, label) != 1:
            failures.append(f"{label}: section_present is not 1")
        if section.get("contiguous") != "T":
            failures.append(f"{label}: contiguous={section.get('contiguous')}")

        expected_offset = as_int(section, "expected_offset", failures, label)
        observed_offset = as_int(section, "observed_offset", failures, label)
        if (
            expected_offset is not None
            and observed_offset is not None
            and expected_offset != observed_offset
        ):
            failures.append(
                f"{label}: offset mismatch expected={expected_offset} "
                f"observed={observed_offset}"
            )

        parent_ngcont = as_int(parent, "ngcont", failures, label)
        section_ngcont = as_int(section, "ngcont", failures, label)
        if (
            parent_ngcont is not None
            and section_ngcont is not None
            and parent_ngcont != section_ngcont
        ):
            failures.append(
                f"{label}: ngcont mismatch parent={parent_ngcont} "
                f"section={section_ngcont}"
            )

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check the five-phase YLM ownership gate in FPSEID diagnostics."
    )
    parser.add_argument("log", type=Path, help="TDDFT stdout/stderr diagnostic log")
    parser.add_argument(
        "--family",
        choices=("ylm",),
        default="ylm",
        help="ownership family to validate (default: ylm)",
    )
    args = parser.parse_args()

    if not args.log.is_file():
        parser.error(f"log does not exist: {args.log}")

    records = parse_records(args.log)
    failures = validate_ylm(records)
    if failures:
        print("FPSEID Step A/B ownership check: FAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("FPSEID Step A/B ownership check: PASS")
    print("  family: YLM")
    print("  phases: 1-5")
    print("  classification: Y1 (parent and section present; offsets match)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
