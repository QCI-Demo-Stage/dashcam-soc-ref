# Camera Capture IP (`cam_capture`)

## Overview

`cam_capture` accepts an 8-bit camera pixel stream, packs RGB888 pixels, buffers
them in a sync FIFO, and presents a ready/valid stream to the DMA engine.
SoC CSR registers for this block live in `soc_csr` at base `0x1000_0000`.

## Ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset (from `rst_sync`) |
| `enable` | in | 1 | Capture enable (`CAM_CTRL.ENABLE`) |
| `frame_w` | in | 16 | Frame width in pixels (`CAM_FRAME_W`) |
| `frame_h` | in | 16 | Frame height in pixels (`CAM_FRAME_H`) |
| `busy` | out | 1 | Capture or FIFO drain in progress |
| `frame_done` | out | 1 | Sticky frame-complete status |
| `cam_vsync` | in | 1 | Frame start pulse |
| `cam_href` | in | 1 | Line active |
| `cam_data` | in | 8 | Pixel byte (R,G,B repeating) |
| `cam_pclk_valid` | in | 1 | Byte valid this cycle |
| `pix_valid` | out | 1 | RGB pixel available |
| `pix_rgb` | out | 24 | Packed `{R,G,B}` |
| `pix_ready` | in | 1 | Downstream accept |

Parameter: `FIFO_DEPTH` (default 8).

## CSR map (via `soc_csr`)

| Offset | Name | Reset | Access | Fields |
|--------|------|-------|--------|--------|
| `0x00` | `CTRL` | `0x0` | rw | `ENABLE[0]`, `IRQ_EN[1]` |
| `0x04` | `STATUS` | `0x0` | ro | `BUSY[0]`, `FRAME_DONE[1]` |
| `0x08` | `FRAME_W` | `0x4` | rw | `WIDTH[15:0]` |
| `0x0C` | `FRAME_H` | `0x4` | rw | `HEIGHT[15:0]` |

Base address: `0x1000_0000`.

## Timing assumptions

- Camera pads are sampled on `clk` (no separate pixel-clock domain in this SoC
  revision). `cam_pclk_valid` qualifies `cam_data` for one cycle.
- Pulse `cam_vsync` for one cycle to start a frame while `enable=1`.
- Three consecutive valid bytes form one RGB888 pixel.
- Wishbone programming of CSRs is completed through `soc_csr` with single-cycle
  registered ACK; configure `FRAME_W`/`FRAME_H` before setting `ENABLE`.
- FIFO backpressure stalls byte acceptance when full (overflow sticky internal).

## Software usage example

```c
#include "cam_regs.h"

*(volatile uint32_t *)CAM_FRAME_W_ADDR = 4;
*(volatile uint32_t *)CAM_FRAME_H_ADDR = 4;
*(volatile uint32_t *)CAM_CTRL_ADDR    = CAM_CTRL_ENABLE_MASK;

/* wait for FRAME_DONE */
while (!(*(volatile uint32_t *)CAM_STATUS_ADDR & CAM_STATUS_FRAME_DONE_MASK))
    ;
```

## Integration notes

- Instantiated in `dashcam_soc_top` as `u_cam`.
- Pixel stream connects directly to `dma_engine`.
- `frame_done` feeds `irq_ctrl` camera IRQ input.
