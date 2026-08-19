#!/usr/bin/env python3
"""Validate csv/register_spec.csv for Dashcam SoC register map.

Checks (Wishbone B4 / OpenTitan-style address-map hygiene):
  - Required columns: name, address, width, access
  - Unique register names and non-overlapping addresses
  - 4-byte (word) alignment of every address
  - Width is a positive multiple of 8 and spans do not collide
  - CSR registers live in window 0x1000_0000 (addr[31:28] == 0x1)
  - SRAM window entry lives at 0x2000_0000 (addr[31:28] == 0x2)
  - Access type is one of the allowed encodings

Usage:
  python3 scripts/csv_validation.py
  python3 scripts/csv_validation.py -i csv/register_spec.csv
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = ROOT / "csv" / "register_spec.csv"

CSR_WINDOW_BASE = 0x10000000
SRAM_WINDOW_BASE = 0x20000000
CSR_WINDOW_PREFIX = 0x1
SRAM_WINDOW_PREFIX = 0x2

ALLOWED_ACCESS = {"ro", "rw", "wo", "w1c", "rw1c", "rc", "wr"}
REQUIRED_COLUMNS = ("name", "address", "width", "access")


def parse_int(value: str | int) -> int:
    if isinstance(value, int):
        return value
    return int(str(value).strip(), 0)


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise ValueError("CSV has no header row")
        headers = [h.strip() for h in reader.fieldnames]
        missing = [c for c in REQUIRED_COLUMNS if c not in headers]
        if missing:
            raise ValueError(f"missing required columns: {', '.join(missing)}")
        rows: list[dict[str, str]] = []
        for i, raw in enumerate(reader, start=2):
            if raw is None or all((v is None or str(v).strip() == "") for v in raw.values()):
                continue
            row = {k.strip(): ("" if v is None else str(v).strip()) for k, v in raw.items()}
            for col in REQUIRED_COLUMNS:
                if not row.get(col):
                    raise ValueError(f"line {i}: empty value for '{col}'")
            rows.append(row)
        return rows


def validate(rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    names: dict[str, int] = {}
    # (start, end_exclusive, name)
    spans: list[tuple[int, int, str]] = []
    saw_sram = False

    for idx, row in enumerate(rows, start=2):
        name = row["name"]
        try:
            address = parse_int(row["address"])
            width = parse_int(row["width"])
        except ValueError as exc:
            errors.append(f"line {idx} ({name}): invalid integer ({exc})")
            continue

        access = row["access"].lower()
        if access not in ALLOWED_ACCESS:
            errors.append(
                f"line {idx} ({name}): invalid access '{row['access']}' "
                f"(allowed: {sorted(ALLOWED_ACCESS)})"
            )

        if name in names:
            errors.append(
                f"line {idx}: duplicate name '{name}' (also at line {names[name]})"
            )
        else:
            names[name] = idx

        if address < 0:
            errors.append(f"line {idx} ({name}): address must be non-negative")

        if address % 4 != 0:
            errors.append(
                f"line {idx} ({name}): address 0x{address:08X} is not 4-byte aligned "
                "(Wishbone word alignment)"
            )

        if width <= 0 or width % 8 != 0:
            errors.append(
                f"line {idx} ({name}): width {width} must be a positive multiple of 8"
            )
            continue

        byte_width = width // 8
        end = address + byte_width
        for start_o, end_o, other in spans:
            if address < end_o and start_o < end:
                errors.append(
                    f"line {idx} ({name}): address span "
                    f"[0x{address:08X}, 0x{end:08X}) overlaps "
                    f"{other} [0x{start_o:08X}, 0x{end_o:08X})"
                )
        spans.append((address, end, name))

        prefix = (address >> 28) & 0xF
        if name.upper() == "SRAM" or name.upper().startswith("SRAM_"):
            saw_sram = True
            if address != SRAM_WINDOW_BASE:
                errors.append(
                    f"line {idx} ({name}): SRAM window must be at "
                    f"0x{SRAM_WINDOW_BASE:08X}, got 0x{address:08X}"
                )
            if prefix != SRAM_WINDOW_PREFIX:
                errors.append(
                    f"line {idx} ({name}): SRAM entry must sit in window "
                    f"0x{SRAM_WINDOW_BASE:08X}"
                )
        else:
            if prefix != CSR_WINDOW_PREFIX:
                errors.append(
                    f"line {idx} ({name}): CSR register 0x{address:08X} must sit in "
                    f"window 0x{CSR_WINDOW_BASE:08X} (addr[31:28]==0x1)"
                )

    if not rows:
        errors.append("CSV contains no register rows")
    if not saw_sram:
        errors.append(
            f"missing SRAM window entry at 0x{SRAM_WINDOW_BASE:08X} "
            "(expected name SRAM or SRAM_*)"
        )

    # Absolute address uniqueness (independent of width overlap messaging)
    addr_owners: dict[int, str] = {}
    for start, _end, name in spans:
        if start in addr_owners and addr_owners[start] != name:
            errors.append(
                f"duplicate address 0x{start:08X}: '{addr_owners[start]}' and '{name}'"
            )
        addr_owners[start] = name

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate Dashcam SoC register CSV")
    parser.add_argument(
        "-i",
        "--input",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Register CSV (default: {DEFAULT_CSV.relative_to(ROOT)})",
    )
    args = parser.parse_args(argv)

    if not args.input.exists():
        print(f"error: missing register CSV {args.input}", file=sys.stderr)
        return 1

    try:
        rows = load_rows(args.input)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    errors = validate(rows)
    if errors:
        print(f"csv_validation: FAILED ({len(errors)} issue(s))", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"csv_validation: OK ({len(rows)} registers, "
        f"CSR @ 0x{CSR_WINDOW_BASE:08X}, SRAM @ 0x{SRAM_WINDOW_BASE:08X})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
