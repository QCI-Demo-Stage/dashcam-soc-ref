// SRAM controller stub with behavioral memory (PDK-free).
// Window base 0x2000_0000 — 4 KiB word-addressable model for smoke.
`timescale 1ns / 1ps

module sram_ctrl #(
    parameter int DEPTH_WORDS = 1024
) (
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
    output logic        wb_ack
);
    logic [31:0] mem [0:DEPTH_WORDS-1];
    logic        req;
    logic [9:0]  idx;

    assign req = wb_cyc & wb_stb;
    // Word index from byte address within window (low 10 bits of word addr)
    assign idx = wb_adr[11:2];

    // Silence unused low address bits for lint
    wire unused_adr_lo = |wb_adr[1:0] | |wb_adr[31:12];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack   <= 1'b0;
            wb_dat_r <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    if (wb_sel[0]) mem[idx][7:0]   <= wb_dat_w[7:0];
                    if (wb_sel[1]) mem[idx][15:8]  <= wb_dat_w[15:8];
                    if (wb_sel[2]) mem[idx][23:16] <= wb_dat_w[23:16];
                    if (wb_sel[3]) mem[idx][31:24] <= wb_dat_w[31:24];
                end else begin
                    wb_dat_r <= mem[idx];
                end
            end
        end
    end
endmodule
