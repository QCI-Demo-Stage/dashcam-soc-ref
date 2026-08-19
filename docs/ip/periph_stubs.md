# Peripheral Stub Interfaces

Lightweight stubs for early SoC integration: `sd_spi`, `iomux`, `rst_sync`, and
the reusable Wishbone template `wb_periph_stub`.

## SD-SPI (`sd_spi`)

### Ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `clk` / `rst_n` | in | 1 | Clock / reset |
| `enable` / `cs_n` | in | 1 | From `SDSPI_CTRL` |
| `data_w` | in | 8 | MOSI source byte |
| `data_r` | out | 8 | Deterministic read (`0xDE`/`0xDF` + MISO) |
| `idle` | out | 1 | Always 1 (stub) |
| `done` | out | 1 | High when enabled and selected |
| `spi_sclk/mosi/miso/cs_n` | — | 1 | Pads |

### CSR (via `soc_csr` @ `0x1000_0400`)

| Offset | Name | Access | Notes |
|--------|------|--------|-------|
| `0x00` | `CTRL` | rw | `ENABLE`, `CS_N` |
| `0x04` | `STATUS` | ro | `IDLE`, `DONE` |
| `0x08` | `DATA` | rw | Byte |

### Deterministic behavior

Registered stub: SCLK held low, MOSI = `data_w[7]`, `data_r` returns
`{7'h6F, miso}` when enabled (0xDE/0xDF pattern).

---

## IOMUX (`iomux`)

### Ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `sel` | in | 4 | `IOMUX_CTRL.SEL` |
| `pad_in/out/oe` | — | 8 | Package pads |
| `func_in/out/oe` | — | 8 | Function side |

### CSR (`0x1000_0300`)

| Offset | Name | Access | Fields |
|--------|------|--------|--------|
| `0x00` | `CTRL` | rw | `SEL[3:0]` |

### Behavior

`sel==0`: registered passthrough. Nonzero `sel`: masks `func_in` and ORs into
`pad_oe` (stub policy for early bring-up).

---

## Reset synchronizer (`rst_sync`)

### Ports

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| `clk` | in | 1 | Clock |
| `rst_n_async` | in | 1 | Async active-low reset |
| `rst_n` | out | 1 | Sync deasserted reset |

No Wishbone CSR — board/async reset only. Two-flop synchronizer
(async assert, sync deassert).

---

## Wishbone peripheral stub template (`wb_periph_stub`)

Reusable B4 slave for early CSR placeholders.

| Port | Dir | Width | Purpose |
|------|-----|-------|---------|
| Wishbone B4 slave | — | — | Standard CYC/STB/WE/SEL/ADR/DAT/ACK |
| `ctrl_reg` | out | 32 | CTRL mirror |

| Offset | Behavior |
|--------|----------|
| `0x0` | R/W CTRL (reset = `RESET_CTRL`) |
| other | Read returns `READ_VALUE` (default `0xDEAD_BEEF`) |

IP testbench instantiates three copies named for `SD_SPI_CTRL`, `IOMUX_CFG`,
and `RESET_SYNC` CSR identities.

### Top-level integration

SoC uses functional sideband stubs (`sd_spi`, `iomux`, `rst_sync`) wired through
`soc_csr` / `address_decode` / pads. `sd_spi.done` feeds `irq_ctrl` vector bit 2
(`IRQ_ENABLE.SDSPI`). See [`../integration.md`](../integration.md).
`wb_periph_stub` remains a synthesizable CSR template for IP benches and is not
instantiated inside `dashcam_soc_top`.
