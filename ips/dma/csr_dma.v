// DMA CSR block — Wishbone slave for dma registers (SystemRDL: include/dma_csr.rdl)
`timescale 1ns / 1ps
`include "regs_defines.vh"

module csr_dma (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone slave (strobed only when this block is selected)
    input  logic        wb_cyc,
    input  logic        wb_stb,
    input  logic        wb_we,
    input  logic [3:0]  wb_sel,
    input  logic [31:0] wb_adr,
    input  logic [31:0] wb_dat_w,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,

    // Hardware sideband
    output logic        dma_enable,
    output logic [31:0] dma_dst_addr,
    output logic [31:0] dma_length,
    input  logic        dma_busy,
    input  logic        dma_done
);
    localparam logic [7:0] OFF_CTRL     = 8'h00;
    localparam logic [7:0] OFF_STATUS   = 8'h04;
    localparam logic [7:0] OFF_DST_ADDR = 8'h08;
    localparam logic [7:0] OFF_LENGTH   = 8'h0C;

    logic [31:0] dma_ctrl;
    logic [31:0] dma_dst_r;
    logic [31:0] dma_len_r;

    logic        req;
    logic [7:0]  off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[7:0];

    wire unused_dma_if = |wb_sel | |wb_adr[31:8];

    assign dma_enable   = dma_ctrl[0];
    assign dma_dst_addr = dma_dst_r;
    assign dma_length   = dma_len_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_ctrl  <= 32'h0;
            dma_dst_r <= 32'h2000_0000;
            dma_len_r <= 32'h30; // 4*4*3 = 48 default smoke length
            wb_ack    <= 1'b0;
            wb_dat_r  <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        OFF_CTRL:     dma_ctrl  <= wb_dat_w;
                        OFF_DST_ADDR: dma_dst_r <= wb_dat_w;
                        OFF_LENGTH:   dma_len_r <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        OFF_CTRL:     wb_dat_r <= dma_ctrl;
                        OFF_STATUS:   wb_dat_r <= {30'h0, dma_done, dma_busy};
                        OFF_DST_ADDR: wb_dat_r <= dma_dst_r;
                        OFF_LENGTH:   wb_dat_r <= dma_len_r;
                        default:      wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
