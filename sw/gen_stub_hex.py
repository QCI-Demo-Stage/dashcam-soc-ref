#!/usr/bin/env python3
"""Produce a valid firmware image when no RISC-V toolchain is installed.

Writes a minimal ELF-like payload as a flat hex image (sw/out/firmware.hex)
plus a binary blob (sw/out/firmware.bin) so make sw succeeds portably.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def build_image() -> bytes:
    # Minimal RISC-V RV32I "program":
    #   addi x0, x0, 0   ; nop-ish
    #   jal  x0, 0       ; loop to self
    # Prefixed with a magic banner so the file is recognizable.
    banner = b"DASHCAM_SOC_FW_STUB\x00"
    # Pad banner to 32 bytes
    banner = banner + bytes(32 - len(banner))
    words = [
        0x00000013,  # addi x0, x0, 0
        0x0000006F,  # jal x0, 0 (infinite loop)
        0x10000000,  # CSR window base (metadata)
        0x20000000,  # SRAM window base (metadata)
    ]
    body = b"".join(struct.pack("<I", w) for w in words)
    return banner + body


def write_hex(path: Path, data: bytes) -> None:
    lines: list[str] = []
    # Verilog $readmemh-compatible: one 32-bit word per line
    # Pad to multiple of 4
    pad = (-len(data)) % 4
    data = data + bytes(pad)
    for i in range(0, len(data), 4):
        word = struct.unpack_from("<I", data, i)[0]
        lines.append(f"{word:08x}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--outdir", type=Path, required=True)
    args = parser.parse_args()
    args.outdir.mkdir(parents=True, exist_ok=True)
    data = build_image()
    bin_path = args.outdir / "firmware.bin"
    hex_path = args.outdir / "firmware.hex"
    bin_path.write_bytes(data)
    write_hex(hex_path, data)
    print(f"sw: stub image {bin_path} ({len(data)} bytes)")
    print(f"sw: stub hex   {hex_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
