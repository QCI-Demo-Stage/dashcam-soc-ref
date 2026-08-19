// IRQ controller — latches rising-edge events from IP blocks into pending.
// CSR sideband (ENABLE / PENDING W1C / STATUS) is owned by csr_irq via address_decode.
// Vector assignments (OpenTitan-style fixed bit indices):
//   bit 0 = CAM frame_done
//   bit 1 = DMA transfer done
//   bit 2 = SDSPI transfer done
`timescale 1ns / 1ps

module irq_ctrl #(
    parameter int IRQ_CAM_BIT   = 0,
    parameter int IRQ_DMA_BIT   = 1,
    parameter int IRQ_SDSPI_BIT = 2
) (
    input  logic        clk,
    input  logic        rst_n,

    // Raw interrupt inputs from IP blocks (may be sticky levels)
    input  logic        cam_irq,
    input  logic        dma_irq,
    input  logic        sdspi_irq,

    // CSR sideband
    input  logic [31:0] irq_enable,
    input  logic [31:0] pending_clear,
    output logic [31:0] irq_pending,
    output logic        irq_out
);
    logic [31:0] pending;
    logic        cam_irq_d;
    logic        dma_irq_d;
    logic        sdspi_irq_d;

    logic        cam_rise;
    logic        dma_rise;
    logic        sdspi_rise;
    logic [31:0] set_mask;

    assign cam_rise   = cam_irq   & ~cam_irq_d;
    assign dma_rise   = dma_irq   & ~dma_irq_d;
    assign sdspi_rise = sdspi_irq & ~sdspi_irq_d;

    always_comb begin
        set_mask = 32'h0;
        set_mask[IRQ_CAM_BIT]   = cam_rise;
        set_mask[IRQ_DMA_BIT]   = dma_rise;
        set_mask[IRQ_SDSPI_BIT] = sdspi_rise;
    end

    assign irq_pending = pending;
    assign irq_out     = |(pending & irq_enable);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending    <= 32'h0;
            cam_irq_d  <= 1'b0;
            dma_irq_d  <= 1'b0;
            sdspi_irq_d<= 1'b0;
        end else begin
            cam_irq_d   <= cam_irq;
            dma_irq_d   <= dma_irq;
            sdspi_irq_d <= sdspi_irq;
            // Rising-edge set; W1C clear (clear wins same cycle if both assert)
            pending <= (pending | set_mask) & ~pending_clear;
        end
    end
endmodule
