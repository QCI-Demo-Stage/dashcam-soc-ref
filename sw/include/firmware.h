#ifndef FIRMWARE_H_
#define FIRMWARE_H_

#include <stdint.h>
#include "csr_regs.h"

/* Default bring-up frame: 4x4 RGB888 (matches Verilator smoke). */
#define FW_FRAME_W     4u
#define FW_FRAME_H     4u
#define FW_PIXEL_BYTES 4u /* RGB888 packed into 32-bit Wishbone beats */
#define FW_FRAME_BYTES (FW_FRAME_W * FW_FRAME_H * FW_PIXEL_BYTES)
#define FW_DMA_DST     SRAM_WINDOW_BASE

/* Soft IRQ flag set when IRQ_STATUS reports a handled DMA/CAM event. */
extern volatile uint32_t g_irq_flag;

/* MMIO helpers — volatile CSR accesses through the register map. */
static inline void csr_write(uint32_t addr, uint32_t val)
{
    *(volatile uint32_t *)(uintptr_t)addr = val;
}

static inline uint32_t csr_read(uint32_t addr)
{
    return *(volatile uint32_t *)(uintptr_t)addr;
}

/* Configure DMA destination/length, enable IRQs, start capture, wait. */
void firmware_init_capture(void);
void firmware_enable_irqs(void);
void firmware_start_dma_and_cam(void);
void firmware_irq_poll_loop(void);

int main(void);

#endif /* FIRMWARE_H_ */
