// IOMUX CSR block — Wishbone slave for iomux registers (SystemRDL: include/iomux_csr.rdl)
`timescale 1ns / 1ps
`include "regs_defines.vh"

module csr_iomux (
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
    output logic [3:0]  iomux_sel
);
    localparam logic [7:0] OFF_CTRL = 8'h00;

    logic [31:0] iomux_ctrl;

    logic        req;
    logic [7:0]  off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[7:0];

    wire unused_iomux_if = |wb_sel | |wb_adr[31:8];

    assign iomux_sel = iomux_ctrl[3:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iomux_ctrl <= 32'h0;
            wb_ack     <= 1'b0;
            wb_dat_r   <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        OFF_CTRL: iomux_ctrl <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        OFF_CTRL: wb_dat_r <= iomux_ctrl;
                        default:  wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
