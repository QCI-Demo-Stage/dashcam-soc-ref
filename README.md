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
| `sw` | Firmware image (RISC-V GCC or Python stub fallback) |
| `synth` | Yosys generic `synth -top dashcam_soc_top` |

## Layout

- `ips/<block>/rtl/` — IP block RTL
- `top/rtl/` — `dashcam_soc_top`
- `dv/sim/verilator_smoke/` — smoke harness
- `dv/ip/<block>/` — per-IP Verilator testbenches
- `sw/` — firmware
- `csv/` — register address-map source of truth (`register_spec.csv`)
- `include/` — generated per-IP SystemRDL and Verilog CSR `define`s
- `scripts/` — `reggen.py`, `csv_validation.py`, `gen_agent_docs.py`
- `docs/` — register map, [`integration.md`](docs/integration.md), IP specs (`docs/ip/`)

## Hardware notes

- Bus: Wishbone B4
- CSR window: `0x1000_0000`
- SRAM window: `0x2000_0000`
- `USE_CPU`: external Wishbone master (default) or picoRV32
