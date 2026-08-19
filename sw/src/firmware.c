/* Dashcam SoC firmware — configure DMA, start camera capture, handle IRQs.
 *
 * Built for bare-metal RV32 (picoRV32 / USE_CPU=1). Uses generated CSR
 * headers under sw/include/ (*_regs.h / csr_regs.h).
 */

#include "firmware.h"

/* Software-visible interrupt flag (set when IRQ_STATUS is non-zero). */
volatile uint32_t g_irq_flag;

/* Volatile CSR pointers derived from the register map bases. */
static volatile uint32_t *const reg_cam_ctrl =
    (volatile uint32_t *)(uintptr_t)CAM_CTRL_ADDR;
static volatile uint32_t *const reg_cam_status =
    (volatile uint32_t *)(uintptr_t)CAM_STATUS_ADDR;
static volatile uint32_t *const reg_cam_frame_w =
    (volatile uint32_t *)(uintptr_t)CAM_FRAME_W_ADDR;
static volatile uint32_t *const reg_cam_frame_h =
    (volatile uint32_t *)(uintptr_t)CAM_FRAME_H_ADDR;

static volatile uint32_t *const reg_dma_ctrl =
    (volatile uint32_t *)(uintptr_t)DMA_CTRL_ADDR;
static volatile uint32_t *const reg_dma_status =
    (volatile uint32_t *)(uintptr_t)DMA_STATUS_ADDR;
static volatile uint32_t *const reg_dma_dst =
    (volatile uint32_t *)(uintptr_t)DMA_DST_ADDR_ADDR;
static volatile uint32_t *const reg_dma_length =
    (volatile uint32_t *)(uintptr_t)DMA_LENGTH_ADDR;

static volatile uint32_t *const reg_irq_enable =
    (volatile uint32_t *)(uintptr_t)IRQ_ENABLE_ADDR;
static volatile uint32_t *const reg_irq_pending =
    (volatile uint32_t *)(uintptr_t)IRQ_PENDING_ADDR;
static volatile uint32_t *const reg_irq_status =
    (volatile uint32_t *)(uintptr_t)IRQ_STATUS_ADDR;

void firmware_init_capture(void)
{
    /* CAM_FRAME_W: program capture width in pixels. */
    *reg_cam_frame_w = FW_FRAME_W;

    /* CAM_FRAME_H: program capture height in pixels. */
    *reg_cam_frame_h = FW_FRAME_H;

    /* DMA_DST_ADDR: pixel sink in on-chip SRAM window. */
    *reg_dma_dst = FW_DMA_DST;

    /* DMA_LENGTH: total byte count for one frame transfer. */
    *reg_dma_length = FW_FRAME_BYTES;
}

void firmware_enable_irqs(void)
{
    /* IRQ_ENABLE: unmask camera + DMA sources in the IRQ controller. */
    *reg_irq_enable = IRQ_ENABLE_CAM_MASK | IRQ_ENABLE_DMA_MASK;

    /* DMA_CTRL.IRQ_EN: ask the DMA engine to raise done IRQs. */
    *reg_dma_ctrl = DMA_CTRL_IRQ_EN_MASK;

    /* CAM_CTRL.IRQ_EN: ask the camera block to raise frame-done IRQs.
     * ENABLE is left clear until firmware_start_dma_and_cam(). */
    *reg_cam_ctrl = CAM_CTRL_IRQ_EN_MASK;
}

void firmware_start_dma_and_cam(void)
{
    /* DMA_CTRL: enable engine + IRQ (DMA_START). */
    *reg_dma_ctrl = DMA_CTRL_ENABLE_MASK | DMA_CTRL_IRQ_EN_MASK;

    /* CAM_CTRL: enable capture + IRQ so pixels flow into DMA. */
    *reg_cam_ctrl = CAM_CTRL_ENABLE_MASK | CAM_CTRL_IRQ_EN_MASK;
}

void firmware_irq_poll_loop(void)
{
    for (;;) {
        uint32_t status;
        uint32_t pending;
        uint32_t dma_st;
        uint32_t cam_st;

        /* IRQ_STATUS: enabled-and-pending snapshot (cam | dma). */
        status = *reg_irq_status;
        if (status == 0u) {
            /* Also poll DMA_STATUS.DONE as a bring-up fallback when the
             * IRQ line is not yet wired into a CPU trap handler. */
            dma_st = *reg_dma_status;
            if ((dma_st & DMA_STATUS_DONE_MASK) == 0u) {
                continue;
            }
        }

        g_irq_flag = 1u;

        /* IRQ_PENDING: read sticky sources, then W1C-clear what we saw. */
        pending = *reg_irq_pending;
        if (pending != 0u) {
            *reg_irq_pending = pending;
        }

        /* DMA_STATUS: observe done/busy for software bookkeeping. */
        dma_st = *reg_dma_status;
        (void)dma_st;

        /* CAM_STATUS: observe frame_done/busy. */
        cam_st = *reg_cam_status;
        (void)cam_st;

        /* Retire DMA enable so DONE can clear on the next start. */
        *reg_dma_ctrl = 0u;

        /* Hold here after the first completed frame (smoke / bring-up). */
        for (;;) {
            /* idle */
        }
    }
}

int main(void)
{
    g_irq_flag = 0u;

    firmware_init_capture();
    firmware_enable_irqs();
    firmware_start_dma_and_cam();
    firmware_irq_poll_loop();

    return 0;
}
