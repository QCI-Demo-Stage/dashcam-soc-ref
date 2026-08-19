# Smoke Test Report — Dashcam SoC

Full-chip Verilator smoke validation of the integrated `dashcam_soc_top`
(Wishbone fabric + camera capture, DMA, SRAM, and peripheral stubs).

**Date:** 2026-08-19  
**Branch:** `tymeline-aetop-level-ip-integration-ac68`  
**Commit under test:** `33997dc`  
**Outcome:** **PASS**

## Setup

- Repository root: `/workspace` (Dashcam SoC)
- Simulator: Verilator 5.020
- Flow: `dv/sim/verilator_smoke` via root `make sim`
- Design under test: integrated top with CSR window `@ 0x1000_0000` and SRAM
  window `@ 0x2000_0000` (`USE_CPU=0` external Wishbone master in smoke)
- Host: Linux cloud agent environment with Verilator and g++ available

## Commands

From the repository root:

```bash
TIMEFORMAT=$'real %R\nuser %U\nsys %S'
{ time make sim; } 2>&1 | tee /tmp/smoke_sim_output.txt
```

Post-run checks:

```bash
test -f dv/sim/verilator_smoke/out/frame_0000.ppm
grep SMOKE_PASS /tmp/smoke_sim_output.txt
# also present in: dv/sim/verilator_smoke/out/sim.log
```

## Timing

Wall-clock and CPU time for a clean `make sim` (rebuild + run):

| Metric | Value (seconds) |
|--------|-----------------|
| real   | 6.913           |
| user   | 6.042           |
| sys    | 0.588           |

Simulation completed without hitting the testbench global / DMA timeouts.
Build + execute finished well under a typical interactive performance budget
(~7 s end-to-end on this host).

## Results

| Check | Expected | Observed |
|-------|----------|----------|
| `make sim` exit status | 0 | 0 |
| Console / log marker | `SMOKE_PASS` | Present (`sim.log`, make summary) |
| Frame artifact | `dv/sim/verilator_smoke/out/frame_0000.ppm` | Present (191 bytes) |
| PPM header | ASCII Netpbm P3 | `P3` / `4×4` / maxval `255` |
| Make summary | `sim: OK (SMOKE_PASS + frame_0000.ppm)` | Matched |

Sample PPM header:

```text
P3
          4           4
255
16 64 128
...
```

End-to-end path exercised: external Wishbone programming of CAM/DMA CSRs →
`cam_capture` pixel stream → `dma_engine` write into `sram_ctrl` → host readback
and PPM dump → `SMOKE_PASS`.

## Next Steps

1. Keep `make regs && make lint && make sim && make sw && make synth` green on
   subsequent integration changes.
2. Optionally add a CI job that fails if `SMOKE_PASS` is missing or
   `frame_0000.ppm` is absent after `make sim`.
3. Extend coverage beyond the 4×4 smoke frame (larger frames, IRQ path with
   `USE_CPU=1`, SD-SPI / IOMUX CSR access) once the smoke gate remains stable.
4. Re-run this report procedure after any interconnect, CSR map, or datapath
   change that could affect DMA completion or PPM generation.
