// picoRV32 Wishbone master stub — interface-complete placeholder.
// When USE_CPU=1 the top selects this master; stub holds bus idle.
`timescale 1ns / 1ps

module picorv32_wb (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        irq,

    // Wishbone master
    output logic        wb_cyc,
    output logic        wb_stb,
    output logic        wb_we,
    output logic [3:0]  wb_sel,
    output logic [31:0] wb_adr,
    output logic [31:0] wb_dat_w,
    input  logic [31:0] wb_dat_r,
    input  logic        wb_ack
);
    // Stub: never asserts the bus. Real picoRV32 lands in a later story.
    assign wb_cyc   = 1'b0;
    assign wb_stb   = 1'b0;
    assign wb_we    = 1'b0;
    assign wb_sel   = 4'h0;
    assign wb_adr   = 32'h0;
    assign wb_dat_w = 32'h0;

    logic unused;
    assign unused = clk ^ rst_n ^ irq ^ wb_ack ^ ^wb_dat_r;
endmodule
