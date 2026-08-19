// SD-SPI CSR block — Wishbone slave for sdspi registers (SystemRDL: include/sdspi_csr.rdl)
`timescale 1ns / 1ps
`include "regs_defines.vh"

module csr_sdspi (
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
    output logic        sdspi_enable,
    output logic        sdspi_cs_n,
    output logic [7:0]  sdspi_data_w,
    input  logic [7:0]  sdspi_data_r,
    input  logic        sdspi_idle,
    input  logic        sdspi_done
);
    localparam logic [7:0] OFF_CTRL   = 8'h00;
    localparam logic [7:0] OFF_STATUS = 8'h04;
    localparam logic [7:0] OFF_DATA   = 8'h08;

    logic [31:0] sdspi_ctrl;
    logic [31:0] sdspi_data;

    logic        req;
    logic [7:0]  off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[7:0];

    wire unused_sdspi_if = |wb_sel | |wb_adr[31:8] | |sdspi_data[31:8];

    assign sdspi_enable = sdspi_ctrl[0];
    assign sdspi_cs_n   = sdspi_ctrl[1];
    assign sdspi_data_w = sdspi_data[7:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdspi_ctrl <= 32'h0;
            sdspi_data <= 32'h0;
            wb_ack     <= 1'b0;
            wb_dat_r   <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        OFF_CTRL: sdspi_ctrl <= wb_dat_w;
                        OFF_DATA: sdspi_data <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        OFF_CTRL:   wb_dat_r <= sdspi_ctrl;
                        OFF_STATUS: wb_dat_r <= {30'h0, sdspi_done, sdspi_idle};
                        OFF_DATA:   wb_dat_r <= {24'h0, sdspi_data_r};
                        default:    wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
