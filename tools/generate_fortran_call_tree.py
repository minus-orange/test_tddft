#!/usr/bin/env python3
"""Generate a simple static call tree from Fortran source files."""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path


DEF_RE = re.compile(
    r"^\s*(?:(?:recursive|pure|elemental)\s+)?"
    r"(?:(?:integer|real|double\s+precision|complex|logical|character)"
    r"(?:\*\d+|\s*\([^)]*\))?\s+)?"
    r"(program|subroutine|function)\s+([a-z_][a-z0-9_]*)\b",
    re.IGNORECASE,
)
CALL_RE = re.compile(r"\bcall\s+([a-z_][a-z0-9_]*)\b", re.IGNORECASE)
END_RE = re.compile(r"^\s*end\s*(program|subroutine|function)?\b", re.IGNORECASE)


def strip_inline_comment(line: str) -> str:
    in_string = False
    quote = ""
    out = []
    for ch in line:
        if in_string:
            out.append(ch)
            if ch == quote:
                in_string = False
            continue
        if ch in ("'", '"'):
            in_string = True
            quote = ch
            out.append(ch)
            continue
        if ch == "!":
            break
        out.append(ch)
    return "".join(out)


def logical_lines(path: Path) -> list[tuple[int, str]]:
    result: list[tuple[int, str]] = []
    current = ""
    start_line = 0

    for lineno, raw in enumerate(path.read_text(errors="ignore").splitlines(), 1):
        if not raw.strip():
            continue
        if raw[0:1] in ("c", "C", "*", "!"):
            continue

        line = strip_inline_comment(raw.rstrip())
        if not line.strip():
            continue

        is_fixed_cont = len(line) >= 6 and line[:5].strip() == "" and line[5:6].strip() not in ("", "0")
        is_free_cont = current.rstrip().endswith("&")

        if is_fixed_cont:
            current = current.rstrip("& ") + " " + line[6:].strip()
            continue
        if is_free_cont:
            current = current.rstrip("& ") + " " + line.strip().lstrip("&").strip()
            continue

        if current:
            result.append((start_line, current))
        current = line
        start_line = lineno

    if current:
        result.append((start_line, current))
    return result


def parse_sources(paths: list[Path]) -> tuple[dict[str, dict], dict[str, list[str]]]:
    routines: dict[str, dict] = {}
    calls: dict[str, list[str]] = defaultdict(list)
    current = None

    for path in paths:
        implicit_main = path.name == "pspw_tm11_Vext_Avec_v4_alloc.f"
        if implicit_main:
            current = "pspw"

        for lineno, stmt in logical_lines(path):
            lowered = stmt.lower()
            match = DEF_RE.match(lowered)
            if match:
                current = match.group(2).lower()
                routines[current] = {
                    "kind": match.group(1).lower(),
                    "file": str(path),
                    "line": lineno,
                }
                continue

            if current is None:
                continue

            if END_RE.match(lowered) and not implicit_main:
                current = None
                continue

            for called in CALL_RE.findall(lowered):
                called = called.lower()
                if called not in calls[current]:
                    calls[current].append(called)

        if implicit_main:
            current = None

    return routines, calls


def render_tree(root: str, routines: dict[str, dict], calls: dict[str, list[str]], include_external: bool) -> list[str]:
    lines: list[str] = []

    def walk(name: str, depth: int, stack: list[str]) -> None:
        if name in stack:
            lines.append(f"{'  ' * depth}- {name} [recursive]")
            return

        info = routines.get(name)
        if info:
            label = f"{name} ({info['file']}:{info['line']})"
        elif include_external:
            label = f"{name} [external]"
        else:
            return

        lines.append(f"{'  ' * depth}- {label}")
        for child in calls.get(name, []):
            if include_external or child in routines:
                walk(child, depth + 1, stack + [name])

    walk(root.lower(), 0, [])
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("sources", nargs="+", type=Path)
    parser.add_argument("--root", default="pspw")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--include-external", action="store_true")
    args = parser.parse_args()

    paths = [p for p in args.sources if p.exists()]
    routines, calls = parse_sources(paths)
    root = args.root.lower()

    out: list[str] = [
        "# TDDFT static call tree",
        "",
        "Generated from Fortran `program` / `subroutine` / `function` definitions and `call` statements.",
        "This is a static approximation; calls through external libraries, alternate entry points, and conditional runtime paths require profiling data to confirm.",
        "",
        f"Root: `{root}`",
        "",
        "```text",
    ]
    out.extend(render_tree(root, routines, calls, args.include_external))
    out.extend(["```", ""])

    called = {c for values in calls.values() for c in values}
    unresolved = sorted(c for c in called if c not in routines)
    out.extend(
        [
            "## Summary",
            "",
            f"- Parsed source files: {len(paths)}",
            f"- Defined routines: {len(routines)}",
            f"- Unresolved/external calls: {len(unresolved)}",
            "",
        ]
    )

    if unresolved:
        out.extend(["## Unresolved/external calls", ""])
        for name in unresolved:
            out.append(f"- `{name}`")
        out.append("")

    text = "\n".join(out)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
