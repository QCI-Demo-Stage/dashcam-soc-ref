# Dashcam SoC

Wishbone-based RISC-V dashcam reference SoC. Synthesis stays PDK-free; Sky130
is collateral only.

## Self-check contract

From the repository root:

```bash
make regs && make lint && make sim && make sw && make synth
```

| Target | Purpose |
|--------|---------|
| `regs` | Validate register CSV; emit `include/*_csr.rdl`, `include/regs_defines.vh`, CSR headers, docs |
| `lint` | Verilator lint of synthesizable RTL + `AGENTS.md` freshness |
| `sim` | Verilator smoke (`SMOKE_PASS` + PPM) |
| `ip_sim` | Per-IP Verilator benches (cam/dma/sram/peripherals) |
| `sw` | Firmware image → `sw/out/firmware.hex` (RISC-V GCC or stub fallback) |
| `synth` | PDK-free Yosys via `synth.tcl` + `synth_constraints.sdc` (≤15 k gates) |

## Firmware

`make sw` builds minimal RV32 firmware that programs DMA/camera/IRQ CSRs.
With a RISC-V toolchain it compiles `sw/src/firmware.c`; otherwise it copies
`sw/stub/firmware_stub.hex`. Details: [`docs/firmware.md`](docs/firmware.md).

## Layout

- `ips/<block>/rtl/` — functional IP block RTL stubs
- `fips/<block>/rtl/` — fabric IP stubs (Wishbone interconnect, reset sync, CPU master)
- `top/rtl/` — `dashcam_soc_top`
- `dv/sim/verilator_smoke/` — smoke harness
- `dv/ip/<block>/` — per-IP Verilator testbenches
- `sw/` — firmware sources, CSR headers, stub hex
- `csv/` — register address-map source of truth (`register_spec.csv`)
- `include/` — generated per-IP SystemRDL and Verilog CSR `define`s
- `scripts/` — `reggen.py`, `csv_validation.py`, `gen_agent_docs.py`
- `docs/` — register map, [`integration.md`](docs/integration.md), [`firmware.md`](docs/firmware.md), [`synthesis.md`](docs/synthesis.md), IP specs (`docs/ip/`)
- `synth.tcl` / `synth_constraints.sdc` — PDK-free Yosys synthesis + generic SDC

## Hardware notes

- Bus: Wishbone B4
- CSR window: `0x1000_0000`
- SRAM window: `0x2000_0000`
- `USE_CPU`: external Wishbone master (default) or picoRV32
