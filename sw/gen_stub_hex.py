#!/usr/bin/env python3
"""Produce a valid firmware image when no RISC-V toolchain is installed.

Emits:
  - sw/stub/firmware_stub.hex  (committed fallback artifact)
  - sw/out/firmware.hex        (build output, gitignored)
  - sw/out/firmware.bin

The payload matches sw/stub/stub.S: nop + infinite jal loop, plus a small
banner/metadata prefix so the image is recognizable in $readmemh dumps.
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path


def build_image() -> bytes:
    # Banner + pad to 32 bytes, then RV32I words from stub.S:
    #   addi x0, x0, 0
    #   jal  x0, 0          ; loop to self
    # followed by CSR/SRAM window metadata words.
    banner = b"DASHCAM_SOC_FW_STUB\x00"
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
    pad = (-len(data)) % 4
    data = data + bytes(pad)
    lines = [
        f"{struct.unpack_from('<I', data, i)[0]:08x}"
        for i in range(0, len(data), 4)
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_bin(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main() -> int:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--outdir",
        type=Path,
        default=here / "out",
        help="Directory for firmware.hex / firmware.bin (default: sw/out)",
    )
    parser.add_argument(
        "--stub",
        type=Path,
        default=here / "stub" / "firmware_stub.hex",
        help="Path for the committed fallback stub hex",
    )
    parser.add_argument(
        "--no-stub",
        action="store_true",
        help="Skip writing the committed stub path",
    )
    args = parser.parse_args()

    data = build_image()
    args.outdir.mkdir(parents=True, exist_ok=True)

    bin_path = args.outdir / "firmware.bin"
    hex_path = args.outdir / "firmware.hex"
    write_bin(bin_path, data)
    write_hex(hex_path, data)
    print(f"sw: stub image {bin_path} ({len(data)} bytes)")
    print(f"sw: stub hex   {hex_path}")

    if not args.no_stub:
        write_hex(args.stub, data)
        print(f"sw: fallback   {args.stub}")

    if hex_path.stat().st_size == 0:
        print("error: firmware.hex is empty", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
