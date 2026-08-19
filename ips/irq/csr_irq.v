// IRQ CSR block — Wishbone slave for irq registers (SystemRDL: include/irq_csr.rdl)
`timescale 1ns / 1ps
`include "regs_defines.vh"

module csr_irq (
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
    output logic [31:0] irq_enable,
    input  logic [31:0] irq_pending,
    output logic [31:0] irq_pending_clear
);
    localparam logic [7:0] OFF_ENABLE  = 8'h00;
    localparam logic [7:0] OFF_PENDING = 8'h04;
    localparam logic [7:0] OFF_STATUS  = 8'h08;

    logic [31:0] irq_en_r;
    logic [31:0] irq_pend_clr;

    logic        req;
    logic [7:0]  off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[7:0];

    wire unused_irq_if = |wb_sel | |wb_adr[31:8];

    assign irq_enable        = irq_en_r;
    assign irq_pending_clear = irq_pend_clr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_en_r     <= 32'h0;
            irq_pend_clr <= 32'h0;
            wb_ack       <= 1'b0;
            wb_dat_r     <= 32'h0;
        end else begin
            irq_pend_clr <= 32'h0; // one-cycle W1C pulse
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        OFF_ENABLE:  irq_en_r     <= wb_dat_w;
                        OFF_PENDING: irq_pend_clr <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        OFF_ENABLE:  wb_dat_r <= irq_en_r;
                        OFF_PENDING: wb_dat_r <= irq_pending;
                        OFF_STATUS:  wb_dat_r <= irq_pending & irq_en_r;
                        default:     wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
