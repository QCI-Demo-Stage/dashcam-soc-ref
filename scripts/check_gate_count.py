#!/usr/bin/env python3
"""Extract Yosys `stat` gate count and assert it is <= GATE_LIMIT (default 15000).

Looks for the flattened `dashcam_soc_top` section in a Yosys report and reads
`Number of cells`. Falls back to the maximum cell count in the file if the
top section is missing.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CELL_RE = re.compile(r"Number of cells:\s+(\d+)")
TOP_RE = re.compile(
    r"===+\s*dashcam_soc_top\s*===+\s*(.*?)\n(?:===|\Z)",
    re.DOTALL | re.IGNORECASE,
)


def extract_gate_count(text: str) -> int:
    top = TOP_RE.search(text)
    if top:
        m = CELL_RE.search(top.group(1))
        if m:
            return int(m.group(1))

    counts = [int(m.group(1)) for m in CELL_RE.finditer(text)]
    if not counts:
        raise ValueError("No 'Number of cells' line found in report")
    return max(counts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report",
        type=Path,
        help="Yosys stat report (e.g. synth/stat.rpt or synth/area_gates.rpt)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=15000,
        help="Maximum allowed gate/cell count (default: 15000)",
    )
    args = parser.parse_args()

    if not args.report.is_file():
        print(f"error: report not found: {args.report}", file=sys.stderr)
        return 1

    text = args.report.read_text(encoding="utf-8", errors="replace")
    try:
        gates = extract_gate_count(text)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"gate_count={gates} limit={args.limit} report={args.report}")
    if gates > args.limit:
        print(
            f"error: gate count {gates} exceeds limit {args.limit}",
            file=sys.stderr,
        )
        return 1

    print("gate count check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
