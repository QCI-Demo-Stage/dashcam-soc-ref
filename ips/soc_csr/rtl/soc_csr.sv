// SoC CSR bank — thin wrapper around central address_decode.
// Per-IP csr_* modules own the register storage; this preserves the
// historical soc_csr instance name in the SoC hierarchy.
`timescale 1ns / 1ps

module soc_csr (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone slave
    input  logic        wb_cyc,
    input  logic        wb_stb,
    input  logic        wb_we,
    input  logic [3:0]  wb_sel,
    input  logic [31:0] wb_adr,
    input  logic [31:0] wb_dat_w,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,

    // To camera capture
    output logic        cam_enable,
    output logic [15:0] cam_frame_w,
    output logic [15:0] cam_frame_h,
    input  logic        cam_busy,
    input  logic        cam_frame_done,

    // To DMA
    output logic        dma_enable,
    output logic [31:0] dma_dst_addr,
    output logic [31:0] dma_length,
    input  logic        dma_busy,
    input  logic        dma_done,

    // To IRQ controller
    output logic [31:0] irq_enable,
    input  logic [31:0] irq_pending,
    output logic [31:0] irq_pending_clear,

    // IOMUX / SDSPI shallow
    output logic [3:0]  iomux_sel,
    output logic        sdspi_enable,
    output logic        sdspi_cs_n,
    output logic [7:0]  sdspi_data_w,
    input  logic [7:0]  sdspi_data_r,
    input  logic        sdspi_idle,
    input  logic        sdspi_done
);
    address_decode u_address_decode (
        .clk              (clk),
        .rst_n            (rst_n),
        .wb_cyc           (wb_cyc),
        .wb_stb           (wb_stb),
        .wb_we            (wb_we),
        .wb_sel           (wb_sel),
        .wb_adr           (wb_adr),
        .wb_dat_w         (wb_dat_w),
        .wb_dat_r         (wb_dat_r),
        .wb_ack           (wb_ack),
        .cam_enable       (cam_enable),
        .cam_frame_w      (cam_frame_w),
        .cam_frame_h      (cam_frame_h),
        .cam_busy         (cam_busy),
        .cam_frame_done   (cam_frame_done),
        .dma_enable       (dma_enable),
        .dma_dst_addr     (dma_dst_addr),
        .dma_length       (dma_length),
        .dma_busy         (dma_busy),
        .dma_done         (dma_done),
        .irq_enable       (irq_enable),
        .irq_pending      (irq_pending),
        .irq_pending_clear(irq_pending_clear),
        .iomux_sel        (iomux_sel),
        .sdspi_enable     (sdspi_enable),
        .sdspi_cs_n       (sdspi_cs_n),
        .sdspi_data_w     (sdspi_data_w),
        .sdspi_data_r     (sdspi_data_r),
        .sdspi_idle       (sdspi_idle),
        .sdspi_done       (sdspi_done)
    );
endmodule
