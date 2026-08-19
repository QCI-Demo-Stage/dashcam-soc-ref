// Central Wishbone CSR address decode
// Routes CSR window sub-blocks to per-IP csr_* modules.
`timescale 1ns / 1ps
`include "regs_defines.vh"

module address_decode (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone slave (CSR window @ 0x1000_0000)
    input  logic        wb_cyc,
    input  logic        wb_stb,
    input  logic        wb_we,
    input  logic [3:0]  wb_sel,
    input  logic [31:0] wb_adr,
    input  logic [31:0] wb_dat_w,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,

    // Camera
    output logic        cam_enable,
    output logic [15:0] cam_frame_w,
    output logic [15:0] cam_frame_h,
    input  logic        cam_busy,
    input  logic        cam_frame_done,

    // DMA
    output logic        dma_enable,
    output logic [31:0] dma_dst_addr,
    output logic [31:0] dma_length,
    input  logic        dma_busy,
    input  logic        dma_done,

    // IRQ
    output logic [31:0] irq_enable,
    input  logic [31:0] irq_pending,
    output logic [31:0] irq_pending_clear,

    // IOMUX / SDSPI
    output logic [3:0]  iomux_sel,
    output logic        sdspi_enable,
    output logic        sdspi_cs_n,
    output logic [7:0]  sdspi_data_w,
    input  logic [7:0]  sdspi_data_r,
    input  logic        sdspi_idle,
    input  logic        sdspi_done
);
    // Block selects from absolute address (CSR bases from regs_defines.vh)
    // cam   @ 0x10000000 → adr[11:8] == 4'h0
    // dma   @ 0x10000100 → adr[11:8] == 4'h1
    // irq   @ 0x10000200 → adr[11:8] == 4'h2
    // iomux @ 0x10000300 → adr[11:8] == 4'h3
    // sdspi @ 0x10000400 → adr[11:8] == 4'h4
    logic sel_cam;
    logic sel_dma;
    logic sel_irq;
    logic sel_iomux;
    logic sel_sdspi;

    logic        cam_cyc, cam_stb, cam_ack;
    logic [31:0] cam_dat_r;
    logic        dma_cyc, dma_stb, dma_ack;
    logic [31:0] dma_dat_r;
    logic        irq_cyc, irq_stb, irq_ack;
    logic [31:0] irq_dat_r;
    logic        iomux_cyc, iomux_stb, iomux_ack;
    logic [31:0] iomux_dat_r;
    logic        sdspi_cyc, sdspi_stb, sdspi_ack;
    logic [31:0] sdspi_dat_r;

    always_comb begin
        sel_cam   = 1'b0;
        sel_dma   = 1'b0;
        sel_irq   = 1'b0;
        sel_iomux = 1'b0;
        sel_sdspi = 1'b0;
        unique case (wb_adr[11:8])
            4'h0: sel_cam   = 1'b1;
            4'h1: sel_dma   = 1'b1;
            4'h2: sel_irq   = 1'b1;
            4'h3: sel_iomux = 1'b1;
            4'h4: sel_sdspi = 1'b1;
            default: ;
        endcase
    end

    assign cam_cyc   = wb_cyc & sel_cam;
    assign cam_stb   = wb_stb & sel_cam;
    assign dma_cyc   = wb_cyc & sel_dma;
    assign dma_stb   = wb_stb & sel_dma;
    assign irq_cyc   = wb_cyc & sel_irq;
    assign irq_stb   = wb_stb & sel_irq;
    assign iomux_cyc = wb_cyc & sel_iomux;
    assign iomux_stb = wb_stb & sel_iomux;
    assign sdspi_cyc = wb_cyc & sel_sdspi;
    assign sdspi_stb = wb_stb & sel_sdspi;

    // One-cycle registered ACK for decode misses (unmapped CSR offsets)
    logic miss_ack;
    logic req_miss;

    assign req_miss = wb_cyc & wb_stb & ~(sel_cam | sel_dma | sel_irq | sel_iomux | sel_sdspi);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miss_ack <= 1'b0;
        end else begin
            miss_ack <= 1'b0;
            if (req_miss && !miss_ack)
                miss_ack <= 1'b1;
        end
    end

    always_comb begin
        wb_dat_r = 32'h0;
        wb_ack   = 1'b0;
        unique case (1'b1)
            sel_cam: begin
                wb_dat_r = cam_dat_r;
                wb_ack   = cam_ack;
            end
            sel_dma: begin
                wb_dat_r = dma_dat_r;
                wb_ack   = dma_ack;
            end
            sel_irq: begin
                wb_dat_r = irq_dat_r;
                wb_ack   = irq_ack;
            end
            sel_iomux: begin
                wb_dat_r = iomux_dat_r;
                wb_ack   = iomux_ack;
            end
            sel_sdspi: begin
                wb_dat_r = sdspi_dat_r;
                wb_ack   = sdspi_ack;
            end
            default: begin
                wb_dat_r = 32'h0;
                wb_ack   = miss_ack;
            end
        endcase
    end

    csr_cam u_csr_cam (
        .clk           (clk),
        .rst_n         (rst_n),
        .wb_cyc        (cam_cyc),
        .wb_stb        (cam_stb),
        .wb_we         (wb_we),
        .wb_sel        (wb_sel),
        .wb_adr        (wb_adr),
        .wb_dat_w      (wb_dat_w),
        .wb_dat_r      (cam_dat_r),
        .wb_ack        (cam_ack),
        .cam_enable    (cam_enable),
        .cam_frame_w   (cam_frame_w),
        .cam_frame_h   (cam_frame_h),
        .cam_busy      (cam_busy),
        .cam_frame_done(cam_frame_done)
    );

    csr_dma u_csr_dma (
        .clk         (clk),
        .rst_n       (rst_n),
        .wb_cyc      (dma_cyc),
        .wb_stb      (dma_stb),
        .wb_we       (wb_we),
        .wb_sel      (wb_sel),
        .wb_adr      (wb_adr),
        .wb_dat_w    (wb_dat_w),
        .wb_dat_r    (dma_dat_r),
        .wb_ack      (dma_ack),
        .dma_enable  (dma_enable),
        .dma_dst_addr(dma_dst_addr),
        .dma_length  (dma_length),
        .dma_busy    (dma_busy),
        .dma_done    (dma_done)
    );

    csr_irq u_csr_irq (
        .clk              (clk),
        .rst_n            (rst_n),
        .wb_cyc           (irq_cyc),
        .wb_stb           (irq_stb),
        .wb_we            (wb_we),
        .wb_sel           (wb_sel),
        .wb_adr           (wb_adr),
        .wb_dat_w         (wb_dat_w),
        .wb_dat_r         (irq_dat_r),
        .wb_ack           (irq_ack),
        .irq_enable       (irq_enable),
        .irq_pending      (irq_pending),
        .irq_pending_clear(irq_pending_clear)
    );

    csr_iomux u_csr_iomux (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc   (iomux_cyc),
        .wb_stb   (iomux_stb),
        .wb_we    (wb_we),
        .wb_sel   (wb_sel),
        .wb_adr   (wb_adr),
        .wb_dat_w (wb_dat_w),
        .wb_dat_r (iomux_dat_r),
        .wb_ack   (iomux_ack),
        .iomux_sel(iomux_sel)
    );

    csr_sdspi u_csr_sdspi (
        .clk         (clk),
        .rst_n       (rst_n),
        .wb_cyc      (sdspi_cyc),
        .wb_stb      (sdspi_stb),
        .wb_we       (wb_we),
        .wb_sel      (wb_sel),
        .wb_adr      (wb_adr),
        .wb_dat_w    (wb_dat_w),
        .wb_dat_r    (sdspi_dat_r),
        .wb_ack      (sdspi_ack),
        .sdspi_enable(sdspi_enable),
        .sdspi_cs_n  (sdspi_cs_n),
        .sdspi_data_w(sdspi_data_w),
        .sdspi_data_r(sdspi_data_r),
        .sdspi_idle  (sdspi_idle),
        .sdspi_done  (sdspi_done)
    );
endmodule
