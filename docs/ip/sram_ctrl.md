# Memory Controller IP (`sram_ctrl`)

## Overview

Wishbone B4 SRAM controller with byte-enable writes, registered responses, and
configurable extra wait-state latency (`LATENCY` / `LATENCY_CFG`).

## Wishbone ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Reset |
| `wb_cyc` | in | 1 | Cycle |
| `wb_stb` | in | 1 | Strobe |
| `wb_we` | in | 1 | Write enable |
| `wb_sel` | in | 4 | Byte enables |
| `wb_adr` | in | 32 | Byte address (word index = `adr[11:2]`) |
| `wb_dat_w` | in | 32 | Write data |
| `wb_dat_r` | out | 32 | Read data |
| `wb_ack` | out | 1 | Registered acknowledge |

Parameters:

| Name | Default | Description |
|------|---------|-------------|
| `DEPTH_WORDS` | 1024 | Behavioral memory depth |
| `LATENCY` | 0 | Extra wait states (`LATENCY_CFG`) before ACK |

Internal CTRL/STATUS mirrors (for docs/TB): `ctrl_enable` (sticky 1),
`latency_cfg`, `status_busy`.

## Byte-enable behavior

On writes, each `wb_sel[i]` updates byte lane `i` of the addressed word. Reads
always return the full 32-bit word.

## Latency configuration

With `LATENCY=0`, ACK is issued one clock after the request (same as classic
registered slave). With `LATENCY=N`, the controller inserts `N` additional wait
states after accepting the request before driving `wb_ack`.

SoC integration uses the default (`LATENCY=0`) so the smoke datapath timing is
unchanged. IP-level tests instantiate a second DUT with `LATENCY=2`.

## Software example

```c
#define SRAM_BASE 0x20000000u
volatile uint32_t *sram = (volatile uint32_t *)SRAM_BASE;
sram[0] = 0xA5A55A5Au;
uint32_t v = sram[0];
```

There is no separate CSR window for the memory controller in the SoC map; the
SRAM is the `0x2000_0000` Wishbone slave.
