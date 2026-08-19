/* Tiny Dashcam SoC firmware stub — polls camera/DMA status. */
#include <stdint.h>
#include "cam_regs.h"
#include "dma_regs.h"
#include "irq_regs.h"

static inline void mmio_write(uint32_t addr, uint32_t val) {
    *(volatile uint32_t *)(uintptr_t)addr = val;
}

static inline uint32_t mmio_read(uint32_t addr) {
    return *(volatile uint32_t *)(uintptr_t)addr;
}

int main(void) {
    mmio_write(CAM_FRAME_W_ADDR, 4u);
    mmio_write(CAM_FRAME_H_ADDR, 4u);
    mmio_write(DMA_DST_ADDR_ADDR, 0x20000000u);
    mmio_write(DMA_LENGTH_ADDR, 64u);
    mmio_write(IRQ_ENABLE_ADDR, IRQ_ENABLE_CAM_MASK | IRQ_ENABLE_DMA_MASK);
    mmio_write(DMA_CTRL_ADDR, DMA_CTRL_ENABLE_MASK);
    mmio_write(CAM_CTRL_ADDR, CAM_CTRL_ENABLE_MASK);

    /* Busy-wait for DMA done (simulation / bring-up hook). */
    while ((mmio_read(DMA_STATUS_ADDR) & DMA_STATUS_DONE_MASK) == 0u) {
        /* spin */
    }
    return 0;
}
