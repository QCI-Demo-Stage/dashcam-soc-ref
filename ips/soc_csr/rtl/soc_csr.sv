// SoC CSR bank stub — Wishbone slave covering CSR window registers.
// Implements cam / dma / irq / iomux / sdspi register space shallowly.
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
    // Cam @ 0x10000000
    logic [31:0] cam_ctrl;
    logic [31:0] cam_frame_w_r;
    logic [31:0] cam_frame_h_r;

    // DMA @ 0x10000100
    logic [31:0] dma_ctrl;
    logic [31:0] dma_dst_r;
    logic [31:0] dma_len_r;

    // IRQ @ 0x10000200
    logic [31:0] irq_en_r;
    logic [31:0] irq_pend_clr;

    // IOMUX @ 0x10000300
    logic [31:0] iomux_ctrl;

    // SDSPI @ 0x10000400
    logic [31:0] sdspi_ctrl;
    logic [31:0] sdspi_data;

    logic        req;
    logic [15:0] off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[15:0];

    // Interface bits reserved for later byte-enables / decode
    wire unused_csr_if = |wb_sel | |wb_adr[31:16] | |sdspi_data[31:8];

    assign cam_enable   = cam_ctrl[0];
    assign cam_frame_w  = cam_frame_w_r[15:0];
    assign cam_frame_h  = cam_frame_h_r[15:0];
    assign dma_enable   = dma_ctrl[0];
    assign dma_dst_addr = dma_dst_r;
    assign dma_length   = dma_len_r;
    assign irq_enable   = irq_en_r;
    assign irq_pending_clear = irq_pend_clr;
    assign iomux_sel    = iomux_ctrl[3:0];
    assign sdspi_enable = sdspi_ctrl[0];
    assign sdspi_cs_n   = sdspi_ctrl[1];
    assign sdspi_data_w = sdspi_data[7:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cam_ctrl      <= 32'h0;
            cam_frame_w_r <= 32'h4;
            cam_frame_h_r <= 32'h4;
            dma_ctrl      <= 32'h0;
            dma_dst_r     <= 32'h2000_0000;
            dma_len_r     <= 32'h30; // 4*4*3 = 48
            irq_en_r      <= 32'h0;
            irq_pend_clr  <= 32'h0;
            iomux_ctrl    <= 32'h0;
            sdspi_ctrl    <= 32'h0;
            sdspi_data    <= 32'h0;
            wb_ack        <= 1'b0;
            wb_dat_r      <= 32'h0;
        end else begin
            irq_pend_clr <= 32'h0;
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        16'h0000: cam_ctrl      <= wb_dat_w;
                        16'h0008: cam_frame_w_r <= wb_dat_w;
                        16'h000C: cam_frame_h_r <= wb_dat_w;
                        16'h0100: dma_ctrl      <= wb_dat_w;
                        16'h0108: dma_dst_r     <= wb_dat_w;
                        16'h010C: dma_len_r     <= wb_dat_w;
                        16'h0200: irq_en_r      <= wb_dat_w;
                        16'h0204: irq_pend_clr  <= wb_dat_w;
                        16'h0300: iomux_ctrl    <= wb_dat_w;
                        16'h0400: sdspi_ctrl    <= wb_dat_w;
                        16'h0408: sdspi_data    <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        16'h0000: wb_dat_r <= cam_ctrl;
                        16'h0004: wb_dat_r <= {30'h0, cam_frame_done, cam_busy};
                        16'h0008: wb_dat_r <= cam_frame_w_r;
                        16'h000C: wb_dat_r <= cam_frame_h_r;
                        16'h0100: wb_dat_r <= dma_ctrl;
                        16'h0104: wb_dat_r <= {30'h0, dma_done, dma_busy};
                        16'h0108: wb_dat_r <= dma_dst_r;
                        16'h010C: wb_dat_r <= dma_len_r;
                        16'h0200: wb_dat_r <= irq_en_r;
                        16'h0204: wb_dat_r <= irq_pending;
                        16'h0208: wb_dat_r <= irq_pending & irq_en_r;
                        16'h0300: wb_dat_r <= iomux_ctrl;
                        16'h0400: wb_dat_r <= sdspi_ctrl;
                        16'h0404: wb_dat_r <= {30'h0, sdspi_done, sdspi_idle};
                        16'h0408: wb_dat_r <= {24'h0, sdspi_data_r};
                        default:  wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
