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
| `sw` | Firmware image (RISC-V GCC or Python stub fallback) |
| `synth` | Yosys generic `synth -top dashcam_soc_top` |

## Layout

- `ips/<block>/rtl/` — IP stubs
- `top/rtl/` — `dashcam_soc_top`
- `dv/sim/verilator_smoke/` — smoke harness
- `sw/` — firmware
- `csv/` — register address-map source of truth (`register_spec.csv`)
- `include/` — generated per-IP SystemRDL and Verilog CSR `define`s
- `scripts/` — `reggen.py`, `csv_validation.py`, `gen_agent_docs.py`
- `docs/` — generated register map (Markdown + SystemRDL)

## Hardware notes

- Bus: Wishbone B4
- CSR window: `0x1000_0000`
- SRAM window: `0x2000_0000`
- `USE_CPU`: external Wishbone master (default) or picoRV32
