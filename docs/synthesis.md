# Dashcam SoC — PDK-free synthesis flow

This document describes how `make synth` runs the generic (technology-independent)
Yosys flow with shared SDC constraints, what artifacts land under `synth/`, and
how to extend the flow toward a real PDK later.

## Goals

- Stay **PDK-free**: no Sky130/liberty cells required for the self-check gate.
- Honour generic timing intent from `synth_constraints.sdc` (100 MHz clock,
  async-reset false paths).
- Keep synthesised **logic** under **15 000** cells/gates.
- Preserve behavioral on-chip SRAM as a hierarchical blackbox (not a PDK
  memory-compiler macro).

## Prerequisites

| Tool | Role |
|------|------|
| [Yosys](https://yosyshq.net/yosys/) (≥ 0.33) | Generic RTL → gate netlist |
| Python 3 | `scripts/check_gate_count.py` gate-budget check |
| `find`, `make` | Source discovery / orchestration |

Optional later (not required for `make synth`): OpenSTA / OpenROAD, Sky130
PDK, memory compiler.

## Quick start

From the repository root:

```bash
make synth
```

This:

1. Creates `synth/` if needed.
2. Runs `yosys -s synth.tcl` (same command as CI).
3. Writes netlists and reports under `synth/`.
4. Fails if Yosys exits non-zero **or** the flattened gate count exceeds 15 000.

Equivalent manual invocation:

```bash
yosys -s synth.tcl
python3 scripts/check_gate_count.py synth/stat.rpt --limit 15000
```

## Source files

| Path | Purpose |
|------|---------|
| `synth.tcl` | Public `yosys -s` entry; loads `scripts/synth_pdk_free.tcl` |
| `scripts/synth_pdk_free.tcl` | TCL flow: find/read RTL, SDC, coarse synth, reports |
| `synth_constraints.sdc` | Generic SDC (`create_clock` + false paths) at repo root |
| `scripts/check_gate_count.py` | Parses `stat` report; asserts ≤ 15 k cells |
| `.github/workflows/synth.yml` | CI job: run Yosys, upload reports, check gate count |

## Flow steps (`synth.tcl`)

```text
find ips/ top/  →  *.sv / *.v
        │
        ▼
 read_verilog -sv -Iinclude   (each file)
        │
        ▼
 blackbox sram_ctrl            (behavioral SRAM, PDK-free)
        │
        ▼
 hierarchy -check -top dashcam_soc_top
        │
        ▼
 read_sdc synth_constraints.sdc   (shim; logs "SDC successfully read")
        │
        ▼
 synth -top dashcam_soc_top -run coarse
 opt_clean
 write_verilog synth/dashcam_soc_top.netlist.v
        │
        ▼
 stat  →  synth/stat_hierarchy.rpt
 techmap + flatten + opt_clean
 stat  →  synth/area_gates.rpt , synth/stat.rpt
 write_verilog synth/dashcam_soc_top.mapped.v
```

Notes:

- Yosys 0.33 has no built-in `read_sdc` / `write_report`. `synth.tcl` provides
  TCL shims: `read_sdc` parses and logs the SDC; `write_report` wraps `tee` +
  `stat`.
- `synth -run coarse` continues through the generic fine/check passes (still
  **no** liberty/PDK). This matches the collateral epic’s “coarse then clean
  netlist” sequence while producing a usable gate-level netlist.
- `sram_ctrl` is blackboxed so the 1 Ki×32 behavioral array is **not** exploded
  into tens of thousands of flops during generic techmapping. The controller
  remains a hierarchical behavioral placeholder until a PDK macro is bound.

## SDC constraints

`synth_constraints.sdc` (repository root):

```sdc
create_clock -period 10.0 -name sys_clk [get_ports clk]
set_false_path -from [get_ports async_reset] -to [all_clocks]
set_false_path -from [get_ports rst_n_async] -to [all_clocks]
```

- **sys_clk**: 10 ns period (100 MHz) on port `clk`.
- **async_reset / rst_n_async**: false paths into all clocks. The SoC top port
  is `rst_n_async` (synchronised by `rst_sync`); `async_reset` is the
  collateral’s logical async-reset name.

The Yosys shim records these constraints and writes
`synth/timing_constraints.rpt` with `SDC successfully read`. Full STA against
the SDC is deferred to a PDK-backed OpenSTA/OpenROAD step.

## Artifacts under `synth/`

| File | Contents |
|------|----------|
| `dashcam_soc_top.netlist.v` | Gate-level netlist after coarse/generic synth |
| `dashcam_soc_top.mapped.v` | Post-`techmap` / flattened netlist |
| `stat_hierarchy.rpt` | Pre-flatten `stat` (hierarchy view) |
| `area_gates.rpt` / `stat.rpt` | Flattened cell/gate tally (budget source) |
| `timing_constraints.rpt` | Echo of applied SDC + read confirmation |

Interpret `stat.rpt`:

- `Number of cells` under `=== dashcam_soc_top ===` is the **gate count** used
  by `scripts/check_gate_count.py`.
- Cell types are Yosys internal gates (`$_AND_`, `$_DFF_*`, …), not Sky130.
- One `sram_ctrl` instance should remain as a blackbox cell.

## Gate budget

Hard limit: **≤ 15 000** cells after flatten.

```bash
python3 scripts/check_gate_count.py synth/stat.rpt --limit 15000
```

CI (`.github/workflows/synth.yml`) runs the same Yosys script, uploads the
report artifacts, and fails the job if Yosys fails or the gate count exceeds
15 000.

## Extending toward a PDK (Sky130)

When moving beyond the PDK-free self-check:

1. **Liberty / techmap** — replace generic `synth` fine stage with
   `synth -top …` + `dfflibmap` / `abc -liberty` using Sky130 liberty files
   (collateral only today).
2. **SRAM macro** — remove `blackbox sram_ctrl` and instantiate a compiled
   SRAM (or OpenRAM) hard macro; keep a behavioral model for simulation only.
3. **STA** — run OpenSTA (or OpenROAD) with `synth_constraints.sdc` on the
   mapped netlist; promote false-path / multicycle exceptions as needed for
   `cam_pclk_valid` and SPI domains.
4. **Makefile** — add a separate `synth-pdk` target; keep `make synth`
   PDK-free so the self-check contract stays green without PDK installs.

Do **not** weaken `make regs`, `make lint`, `make sim`, `make sw`, or the
Verilator smoke `SMOKE_PASS` assertions when extending the flow.
