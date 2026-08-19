# Dashcam SoC Firmware

Minimal bare-metal RISC-V firmware that programs the camera/DMA/IRQ CSRs for
the CPU-enabled SoC configuration (`USE_CPU=1`).

## Build

From the repository root:

```bash
make sw
```

**Output path:** `sw/out/firmware.hex` (also `sw/out/firmware.bin`).

| Environment | Behavior |
|-------------|----------|
| `riscv64-unknown-elf-gcc` or `riscv32-unknown-elf-gcc` present | Compile `sw/src/firmware.c` + `crt0.c` (`-march=rv32imc -nostdlib`), objcopy to binary, emit Verilog `$readmemh` hex |
| No RISC-V toolchain | Copy committed `sw/stub/firmware_stub.hex` → `sw/out/firmware.hex` (Python regenerates the stub if missing) |

Generated images under `sw/out/` are gitignored. The fallback stub under
`sw/stub/` is committed so CI and hosts without a cross-compiler still pass
`make sw` with exit status 0.

Refresh the committed stub after changing `sw/stub/stub.S` / `gen_stub_hex.py`:

```bash
make -C sw stub
```

## Sources

| Path | Role |
|------|------|
| `sw/include/csr_regs.h` | Aggregates generated `*_regs.h` + window bases |
| `sw/include/firmware.h` | MMIO helpers, capture constants, API |
| `sw/src/firmware.c` | CSR writes: frame size, DMA dst/len, IRQ enable, start, IRQ poll loop |
| `sw/src/crt0.c` | `_start` → `main` |
| `sw/stub/stub.S` | No-op boot assembly (infinite loop) |
| `sw/stub/firmware_stub.hex` | Pre-built fallback image |
| `sw/gen_stub_hex.py` | Portable stub generator (no GCC required) |

## Runtime sequence

1. Program `CAM_FRAME_W` / `CAM_FRAME_H` (default 4×4, matches smoke).
2. Program `DMA_DST_ADDR` (`0x2000_0000`) and `DMA_LENGTH`.
3. Enable `IRQ_ENABLE` (CAM|DMA) and per-block `IRQ_EN` bits.
4. Set `DMA_CTRL.ENABLE` then `CAM_CTRL.ENABLE`.
5. Poll `IRQ_STATUS` / `DMA_STATUS.DONE`, W1C-clear `IRQ_PENDING`, idle.

CSR addresses come from the register map generated into `sw/include/*_regs.h`
(`make regs`). See [`register_map.md`](register_map.md) for field detail.

## Relation to Verilator smoke

The default smoke harness (`make sim`) drives the SoC with an external Wishbone
master (`USE_CPU=0`) and programs the same CAM/DMA CSR sequence as this
firmware. After `SMOKE_PASS`, the harness also runs `make -C sw all`, which
builds/copies `firmware.hex` and executes `sw/tests/test_firmware_hex.py`
(`FW_CHECK_PASS` must appear in `dv/sim/verilator_smoke/out/sim.log`).
