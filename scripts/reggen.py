#!/usr/bin/env python3
"""Register-map generator (Python 3 stdlib only).

Address-map source of truth: csv/register_spec.csv (name, address, width, access).
Field-level detail remains in scripts/regs.json and must stay consistent with the CSV.

Generates:
  - sw/include/<block>_regs.h   (per-IP CSR headers for firmware)
  - include/<ip>_csr.rdl        (per-IP SystemRDL CSR blocks)
  - include/regs_defines.vh     (Verilog `define address constants)
  - docs/register_map.md        (markdown register map)
  - docs/register_map.rdl       (aggregate SystemRDL address map)

Conventions follow OpenTitan-style register hygiene (unique offsets, word
alignment, hierarchical block bases on a shared bus map).

Output is deterministic: running twice changes nothing.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SPEC = Path(__file__).resolve().parent / "regs.json"
DEFAULT_CSV = ROOT / "csv" / "register_spec.csv"
SW_INCLUDE = ROOT / "sw" / "include"
INCLUDE = ROOT / "include"
DOCS = ROOT / "docs"
SRAM_WINDOW_BASE = 0x20000000

ACCESS_TO_SW = {
    "ro": "r",
    "rw": "rw",
    "wo": "w",
    "w1c": "rw",
    "rw1c": "rw",
    "rc": "r",
    "wr": "rw",
}


def parse_int(value: str | int) -> int:
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def field_mask(bits: str) -> tuple[int, int, int]:
    """Return (msb, lsb, mask) for a field bit range string."""
    bits = bits.strip()
    if ":" in bits:
        msb_s, lsb_s = bits.split(":", 1)
        msb, lsb = int(msb_s), int(lsb_s)
    else:
        msb = lsb = int(bits)
    if msb < lsb:
        msb, lsb = lsb, msb
    width = msb - lsb + 1
    mask = ((1 << width) - 1) << lsb
    return msb, lsb, mask


def load_spec(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_csv_rows(path: Path) -> list[dict[str, str]]:
    """Parse register CSV with the stdlib csv module."""
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise ValueError(f"{path}: missing header")
        rows: list[dict[str, str]] = []
        for raw in reader:
            if raw is None or all((v is None or str(v).strip() == "") for v in raw.values()):
                continue
            rows.append({k.strip(): ("" if v is None else str(v).strip()) for k, v in raw.items()})
        return rows


def csv_by_address(rows: list[dict[str, str]]) -> dict[int, dict[str, str]]:
    out: dict[int, dict[str, str]] = {}
    for row in rows:
        addr = parse_int(row["address"])
        if addr in out:
            raise ValueError(
                f"duplicate CSV address 0x{addr:08X}: "
                f"{out[addr]['name']} and {row['name']}"
            )
        out[addr] = row
    return out


def cross_check_spec_against_csv(spec: dict, csv_rows: list[dict[str, str]]) -> None:
    """Ensure every JSON CSR register appears in the CSV at the same absolute address."""
    by_addr = csv_by_address(csv_rows)
    missing: list[str] = []
    mismatched: list[str] = []
    for block in spec["blocks"]:
        base = parse_int(block["base"])
        for reg in block["registers"]:
            abs_addr = base + parse_int(reg["offset"])
            expected_name = f"{block['name'].upper()}_{reg['name'].upper()}"
            row = by_addr.get(abs_addr)
            if row is None:
                missing.append(f"{expected_name} @ 0x{abs_addr:08X}")
                continue
            if row["name"].upper() != expected_name:
                mismatched.append(
                    f"0x{abs_addr:08X}: JSON expects {expected_name}, CSV has {row['name']}"
                )
            access = reg.get("access", "rw").lower()
            if row["access"].lower() != access:
                mismatched.append(
                    f"{expected_name}: access JSON={access} CSV={row['access'].lower()}"
                )
            width = parse_int(row["width"])
            if width != 32:
                mismatched.append(f"{row['name']}: CSR width must be 32, got {width}")
    if missing or mismatched:
        parts = []
        if missing:
            parts.append("missing in CSV: " + "; ".join(missing))
        if mismatched:
            parts.append("mismatches: " + "; ".join(mismatched))
        raise ValueError("regs.json vs register_spec.csv — " + " | ".join(parts))


def sw_access(access: str) -> str:
    return ACCESS_TO_SW.get(access.lower(), "rw")


def regs_for_block(
    block: dict, csv_rows: list[dict[str, str]]
) -> list[dict[str, object]]:
    """Return CSV registers belonging to an IP block with relative offsets."""
    prefix = block["name"].upper() + "_"
    base = parse_int(block["base"])
    regs: list[dict[str, object]] = []
    for row in csv_rows:
        name = row["name"].upper()
        if not name.startswith(prefix):
            continue
        addr = parse_int(row["address"])
        regs.append(
            {
                "full_name": row["name"],
                "local_name": name[len(prefix) :],
                "address": addr,
                "offset": addr - base,
                "width": parse_int(row["width"]),
                "access": row["access"].lower(),
            }
        )
    regs.sort(key=lambda r: int(r["offset"]))
    return regs


def gen_ip_systemrdl(block: dict, csv_rows: list[dict[str, str]]) -> str:
    """SystemRDL template for one IP CSR block (relative offsets + access attrs)."""
    ip = block["name"].lower()
    base = parse_int(block["base"])
    desc = block.get("description", f"{ip} CSR block")
    regs = regs_for_block(block, csv_rows)

    lines: list[str] = []
    lines.append(f"// Auto-generated by scripts/reggen.py from csv/register_spec.csv — do not edit.")
    lines.append(f"// IP: {ip}  base: 0x{base:08X}")
    lines.append("")
    lines.append(f"addrmap {ip}_csr {{")
    lines.append(f'    name = "{ip}";')
    lines.append(f'    desc = "{desc}";')
    lines.append("    default regwidth = 32;")
    lines.append("    default accesswidth = 32;")
    lines.append("")

    for reg in regs:
        local = str(reg["local_name"])
        width = int(reg["width"])
        offset = int(reg["offset"])
        access = str(reg["access"])
        lines.append("    reg {")
        lines.append(f'        name = "{local}";')
        lines.append(f"        regwidth = {width};")
        lines.append("        field {")
        lines.append('            name = "data";')
        lines.append(f"            sw = {sw_access(access)};")
        lines.append("            hw = r;")
        lines.append(f"        }} data[{width - 1}:0];")
        lines.append(f"    }} {local} @ 0x{offset:X};")
        lines.append("")

    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def gen_systemrdl(csv_rows: list[dict[str, str]], spec: dict) -> str:
    """Derive a SystemRDL addrmap from the CSV (architecture mapping artifact)."""
    title = spec.get("title", "Dashcam SoC Register Map")
    lines: list[str] = []
    lines.append(f"// {title}")
    lines.append("// Auto-generated by scripts/reggen.py from csv/register_spec.csv — do not edit.")
    lines.append("// Wishbone B4; CSR @ 0x10000000; SRAM @ 0x20000000")
    lines.append("// Address-map style aligned with OpenTitan register conventions.")
    lines.append("")
    lines.append("addrmap dashcam_soc {")
    lines.append('    name = "Dashcam SoC";')
    lines.append('    desc = "Wishbone B4 address map for CSR and on-chip SRAM windows";')
    lines.append("    default regwidth = 32;")
    lines.append("    default accesswidth = 32;")
    lines.append("")

    csr_rows = [r for r in csv_rows if not r["name"].upper().startswith("SRAM")]
    sram_rows = [r for r in csv_rows if r["name"].upper().startswith("SRAM")]

    for row in csr_rows:
        name = row["name"]
        addr = parse_int(row["address"])
        width = parse_int(row["width"])
        access = row["access"].lower()
        lines.append("    reg {")
        lines.append(f'        name = "{name}";')
        lines.append(f"        regwidth = {width};")
        lines.append("        field {")
        lines.append('            name = "data";')
        lines.append(f"            sw = {sw_access(access)};")
        lines.append("            hw = r;")
        lines.append(f"        }} data[{width - 1}:0];")
        lines.append(f"    }} {name} @ 0x{addr:X};")
        lines.append("")

    for row in sram_rows:
        addr = parse_int(row["address"])
        lines.append("    external mem {")
        lines.append('        name = "SRAM";')
        lines.append('        desc = "On-chip SRAM window (4 KiB smoke model)";')
        lines.append("        memwidth = 32;")
        lines.append("        mementries = 1024;")
        lines.append(f"    }} SRAM @ 0x{addr:X};")
        lines.append("")

    if not sram_rows:
        lines.append("    external mem {")
        lines.append('        name = "SRAM";')
        lines.append("        memwidth = 32;")
        lines.append("        mementries = 1024;")
        lines.append(f"    }} SRAM @ 0x{SRAM_WINDOW_BASE:X};")
        lines.append("")

    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def gen_regs_defines(csv_rows: list[dict[str, str]]) -> str:
    """Emit a single Verilog header of `define macros for register addresses."""
    lines: list[str] = []
    lines.append("// Auto-generated by scripts/reggen.py from csv/register_spec.csv — do not edit.")
    lines.append("`ifndef REGS_DEFINES_VH_")
    lines.append("`define REGS_DEFINES_VH_")
    lines.append("")
    for row in csv_rows:
        name = row["name"].upper()
        addr = parse_int(row["address"])
        lines.append(f"`define {name} 0x{addr:08X}")
    lines.append("")
    lines.append("`endif // REGS_DEFINES_VH_")
    lines.append("")
    return "\n".join(lines)


def gen_header(block: dict) -> str:
    name = block["name"].upper()
    base = parse_int(block["base"])
    lines: list[str] = []
    lines.append(f"#ifndef {name}_REGS_H_")
    lines.append(f"#define {name}_REGS_H_")
    lines.append("")
    lines.append(f"/* Auto-generated by scripts/reggen.py — do not edit. */")
    lines.append(f"/* Block: {block['name']} — {block.get('description', '')} */")
    lines.append("")
    lines.append(f"#define {name}_BASE 0x{base:08X}u")
    lines.append("")
    for reg in block["registers"]:
        offset = parse_int(reg["offset"])
        rname = reg["name"].upper()
        lines.append(f"#define {name}_{rname}_OFFSET 0x{offset:X}u")
        lines.append(f"#define {name}_{rname}_ADDR ({name}_BASE + {name}_{rname}_OFFSET)")
        for field in reg.get("fields", []):
            fname = field["name"].upper()
            msb, lsb, mask = field_mask(field["bits"])
            lines.append(f"#define {name}_{rname}_{fname}_LSB {lsb}")
            lines.append(f"#define {name}_{rname}_{fname}_MSB {msb}")
            lines.append(f"#define {name}_{rname}_{fname}_MASK 0x{mask:08X}u")
        lines.append("")
    lines.append(f"#endif /* {name}_REGS_H_ */")
    lines.append("")
    return "\n".join(lines)


def gen_markdown(spec: dict) -> str:
    lines: list[str] = []
    lines.append(f"# {spec.get('title', 'Register Map')}")
    lines.append("")
    lines.append("Auto-generated by `scripts/reggen.py` — do not edit.")
    lines.append("")
    lines.append(f"- Bus: **{spec.get('bus', 'Wishbone')}**")
    lines.append(f"- CSR window: `{spec.get('csr_window_base', '0x10000000')}`")
    lines.append(f"- SRAM window: `{spec.get('sram_window_base', '0x20000000')}`")
    lines.append("")
    for block in spec["blocks"]:
        base = parse_int(block["base"])
        lines.append(f"## {block['name']} @ `0x{base:08X}`")
        lines.append("")
        if block.get("description"):
            lines.append(block["description"])
            lines.append("")
        lines.append("| Offset | Name | Access | Reset | Description |")
        lines.append("|--------|------|--------|-------|-------------|")
        for reg in block["registers"]:
            offset = parse_int(reg["offset"])
            lines.append(
                f"| `0x{offset:02X}` | `{reg['name']}` | {reg.get('access', 'rw')} "
                f"| `{reg.get('reset', '0x0')}` | {reg.get('description', '')} |"
            )
        lines.append("")
        for reg in block["registers"]:
            fields = reg.get("fields", [])
            if not fields:
                continue
            lines.append(f"### {reg['name']}")
            lines.append("")
            lines.append("| Bits | Name | Access | Description |")
            lines.append("|------|------|--------|-------------|")
            for field in fields:
                lines.append(
                    f"| `{field['bits']}` | `{field['name']}` | {field.get('access', 'rw')} "
                    f"| {field.get('description', '')} |"
                )
            lines.append("")
    return "\n".join(lines)


def write_if_changed(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        existing = path.read_text(encoding="utf-8")
        if existing == content:
            return False
    path.write_text(content, encoding="utf-8")
    return True


def _report(path: Path, wrote: bool) -> None:
    rel = path.relative_to(ROOT)
    print(f"reggen: {'wrote' if wrote else 'unchanged'} {rel}")


def generate(spec_path: Path, csv_path: Path) -> int:
    spec = load_spec(spec_path)
    if not csv_path.exists():
        print(f"error: missing register CSV {csv_path}", file=sys.stderr)
        return 1
    try:
        csv_rows = load_csv_rows(csv_path)
        cross_check_spec_against_csv(spec, csv_rows)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    changed = 0

    # Firmware C headers (existing)
    for block in sorted(spec["blocks"], key=lambda b: b["name"]):
        out = SW_INCLUDE / f"{block['name']}_regs.h"
        wrote = write_if_changed(out, gen_header(block))
        changed += int(wrote)
        _report(out, wrote)

    # Per-IP SystemRDL CSR blocks → include/<ip>_csr.rdl
    for block in sorted(spec["blocks"], key=lambda b: b["name"]):
        out = INCLUDE / f"{block['name'].lower()}_csr.rdl"
        wrote = write_if_changed(out, gen_ip_systemrdl(block, csv_rows))
        changed += int(wrote)
        _report(out, wrote)

    # Verilog address `define macros → include/regs_defines.vh
    vh_path = INCLUDE / "regs_defines.vh"
    wrote = write_if_changed(vh_path, gen_regs_defines(csv_rows))
    changed += int(wrote)
    _report(vh_path, wrote)

    md_path = DOCS / "register_map.md"
    wrote = write_if_changed(md_path, gen_markdown(spec))
    changed += int(wrote)
    _report(md_path, wrote)

    rdl_path = DOCS / "register_map.rdl"
    wrote = write_if_changed(rdl_path, gen_systemrdl(csv_rows, spec))
    changed += int(wrote)
    _report(rdl_path, wrote)

    print(f"reggen: done ({changed} file(s) updated)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Dashcam SoC register-map generator")
    parser.add_argument(
        "-i",
        "--input",
        type=Path,
        default=DEFAULT_SPEC,
        help="Register description JSON (default: scripts/regs.json)",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help="Register address-map CSV (default: csv/register_spec.csv)",
    )
    args = parser.parse_args(argv)
    if not args.input.exists():
        print(f"error: missing register spec {args.input}", file=sys.stderr)
        return 1
    return generate(args.input, args.csv)


if __name__ == "__main__":
    sys.exit(main())
