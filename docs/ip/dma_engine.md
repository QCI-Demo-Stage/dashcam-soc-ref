# Simple DMA IP (`dma_engine`)

## Overview

`dma_engine` moves RGB888 pixels from the camera capture stream into on-chip
SRAM using a Wishbone B4 master. CSRs are hosted in `soc_csr` at `0x1000_0100`.

## Ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `clk` / `rst_n` | in | 1 | Clock / reset |
| `enable` | in | 1 | `DMA_CTRL.ENABLE` (start when rising while idle) |
| `dst_addr` | in | 32 | Destination byte address |
| `length` | in | 32 | Transfer length in bytes |
| `busy` / `done` | out | 1 | Status |
| `pix_valid` / `pix_rgb` / `pix_ready` | — | — | Camera stream |
| `wb_cyc/stb/we/sel/adr/dat_w` | out | — | Wishbone master |
| `wb_dat_r` / `wb_ack` | in | — | Wishbone response |

Parameter: `FIFO_DEPTH` (default 4).

## CSR map (via `soc_csr`)

| Offset | Name | Reset | Access | Notes |
|--------|------|-------|--------|-------|
| `0x00` | `CTRL` | `0x0` | rw | `ENABLE` (DMA_START), `IRQ_EN` |
| `0x04` | `STATUS` | `0x0` | ro | `BUSY`, `DONE` (DMA_STATUS) |
| `0x08` | `DST_ADDR` | `0x20000000` | rw | SRAM destination |
| `0x0C` | `LENGTH` | `0x30` | rw | Byte count (BURST_LEN×4 for word bursts) |

Base: `0x1000_0100`.

## Burst operation flow

1. Software programs `DST_ADDR` and `LENGTH`, then sets `CTRL.ENABLE`.
2. DMA enters `ST_RUN`, accepts pixels into a small FIFO.
3. Each pop issues a Wishbone write of `{8'h00, R, G, B}` (`sel=0xF`), address
   advances by 4, `LENGTH` decrements by 4.
4. When remaining bytes hit 0, DMA enters `ST_DONE` (`done=1`).
5. Clearing `ENABLE` returns to idle and clears `done` (software ACK).

Timing: classic Wishbone single writes (CYC/STB until ACK). Bus priority in the
top gives DMA precedence over the external/CPU master while `dma_cyc` is high.

## IRQ semantics

- `done` sticky feeds `irq_ctrl` DMA pending bit.
- Software should enable `DMA_CTRL.IRQ_EN` and `IRQ_ENABLE.DMA`, then clear
  pending via `IRQ_PENDING` W1C and clear `DMA_CTRL.ENABLE` to retire `done`.

## Software example

```c
#include "dma_regs.h"

*(volatile uint32_t *)DMA_DST_ADDR_ADDR = 0x20000000u;
*(volatile uint32_t *)DMA_LENGTH_ADDR   = 4u * 4u * 4u; /* 4x4 pixels */
*(volatile uint32_t *)DMA_CTRL_ADDR     = DMA_CTRL_ENABLE_MASK | DMA_CTRL_IRQ_EN_MASK;
while (!(*(volatile uint32_t *)DMA_STATUS_ADDR & DMA_STATUS_DONE_MASK))
    ;
*(volatile uint32_t *)DMA_CTRL_ADDR = 0; /* ack / stop */
```
