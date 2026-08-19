#!/usr/bin/env python3
"""Validate firmware.hex artifacts used by `make sw`.

Checks the build output (sw/out/firmware.hex) and the committed fallback stub
(sw/stub/firmware_stub.hex) for non-empty, well-formed $readmemh words.
Also spot-checks that firmware.c references the expected CSR symbols so the
software bring-up sequence stays aligned with the Verilator smoke CSR program.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SW = Path(__file__).resolve().parents[1]
EXPECTED_SYMBOLS = (
    "DMA_CTRL_ADDR",
    "DMA_STATUS_ADDR",
    "CAM_CTRL_ADDR",
    "IRQ_ENABLE_ADDR",
    "IRQ_PENDING_ADDR",
    "IRQ_STATUS_ADDR",
)


def load_hex_words(path: Path) -> list[int]:
    if not path.is_file():
        raise FileNotFoundError(f"missing hex file: {path}")
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise ValueError(f"empty hex file: {path}")
    words: list[int] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        tok = line.strip()
        if not tok or tok.startswith("//") or tok.startswith("#"):
            continue
        if not re.fullmatch(r"[0-9a-fA-F]+", tok):
            raise ValueError(f"{path}:{line_no}: invalid hex token {tok!r}")
        words.append(int(tok, 16))
    if not words:
        raise ValueError(f"no hex words in {path}")
    return words


def check_firmware_source(src: Path) -> None:
    text = src.read_text(encoding="utf-8")
    missing = [s for s in EXPECTED_SYMBOLS if s not in text]
    if missing:
        raise AssertionError(f"{src} missing CSR symbols: {missing}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out-hex",
        type=Path,
        default=SW / "out" / "firmware.hex",
    )
    parser.add_argument(
        "--stub-hex",
        type=Path,
        default=SW / "stub" / "firmware_stub.hex",
    )
    parser.add_argument(
        "--src",
        type=Path,
        default=SW / "src" / "firmware.c",
    )
    args = parser.parse_args()

    out_words = load_hex_words(args.out_hex)
    stub_words = load_hex_words(args.stub_hex)
    check_firmware_source(args.src)

    print(f"fw_check: {args.out_hex} ({len(out_words)} words)")
    print(f"fw_check: {args.stub_hex} ({len(stub_words)} words)")
    print(f"fw_check: {args.src} CSR symbols OK")
    print("FW_CHECK_PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 — surface as test failure
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
