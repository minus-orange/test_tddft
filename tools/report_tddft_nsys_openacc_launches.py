#!/usr/bin/env python3
"""Summarize non-cuFFT OpenACC CUDA launch shapes from an Nsight SQLite export."""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path


KERNEL_TABLE = "CUPTI_ACTIVITY_KIND_KERNEL"
OPENACC_NAME = re.compile(r"_gpu(?:\b|\()", re.IGNORECASE)


def columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')}


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Aggregate OpenACC kernel Grid/Block shapes from an Nsight Systems "
            "SQLite export. cuFFT library kernels are excluded."
        )
    )
    parser.add_argument("sqlite", type=Path, help="Nsight Systems SQLite export")
    parser.add_argument("--max-rows", type=int, default=40)
    args = parser.parse_args()

    if not args.sqlite.is_file():
        parser.error(f"SQLite export does not exist: {args.sqlite}")
    if args.max_rows < 1:
        parser.error("--max-rows must be positive")

    connection = sqlite3.connect(f"file:{args.sqlite}?mode=ro", uri=True)
    try:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        if KERNEL_TABLE not in tables or "StringIds" not in tables:
            raise RuntimeError(
                "required Nsight tables are missing: "
                f"{KERNEL_TABLE} and/or StringIds"
            )

        kernel_columns = columns(connection, KERNEL_TABLE)
        required = {
            "start",
            "end",
            "gridX",
            "gridY",
            "gridZ",
            "blockX",
            "blockY",
            "blockZ",
        }
        missing = sorted(required - kernel_columns)
        if missing:
            raise RuntimeError(
                "unsupported Nsight kernel schema; missing columns: "
                + ", ".join(missing)
            )

        name_column = "shortName" if "shortName" in kernel_columns else "demangledName"
        register_expr = (
            "k.registersPerThread" if "registersPerThread" in kernel_columns else "0"
        )
        query = f"""
            SELECT
                s.value,
                k.gridX, k.gridY, k.gridZ,
                k.blockX, k.blockY, k.blockZ,
                {register_expr},
                COUNT(*),
                SUM(k.end - k.start),
                AVG(k.end - k.start)
            FROM {KERNEL_TABLE} AS k
            JOIN StringIds AS s ON s.id = k.{name_column}
            GROUP BY
                s.value,
                k.gridX, k.gridY, k.gridZ,
                k.blockX, k.blockY, k.blockZ,
                {register_expr}
            ORDER BY SUM(k.end - k.start) DESC
        """
        rows = [row for row in connection.execute(query) if OPENACC_NAME.search(row[0])]
    finally:
        connection.close()

    print("FPSEID21_NSYS_OPENACC_LAUNCHES_BEGIN")
    print(f"sqlite={args.sqlite.resolve()}")
    print("cuFFT_excluded=YES openacc_name_filter=_gpu")
    print(
        "total_ms launches grid block threads_per_launch registers_per_thread "
        "avg_us kernel"
    )
    for row in rows[: args.max_rows]:
        (
            name,
            grid_x,
            grid_y,
            grid_z,
            block_x,
            block_y,
            block_z,
            registers,
            launches,
            total_ns,
            average_ns,
        ) = row
        threads = grid_x * grid_y * grid_z * block_x * block_y * block_z
        print(
            f"{total_ns / 1.0e6:.3f} {launches} "
            f"{grid_x}x{grid_y}x{grid_z} {block_x}x{block_y}x{block_z} "
            f"{threads} {registers} {average_ns / 1.0e3:.3f} {name}"
        )
    print(f"configurations={len(rows)} shown={min(len(rows), args.max_rows)}")
    print("FPSEID21_NSYS_OPENACC_LAUNCHES_END")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, sqlite3.Error) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
