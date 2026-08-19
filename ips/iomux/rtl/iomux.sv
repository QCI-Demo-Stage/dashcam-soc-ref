// IOMUX stub — pad function select passthrough
`timescale 1ns / 1ps

module iomux (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [3:0]  sel,

    // Pad side
    input  logic [7:0]  pad_in,
    output logic [7:0]  pad_out,
    output logic [7:0]  pad_oe,

    // Function side (camera / spi / gpio shallow)
    output logic [7:0]  func_in,
    input  logic [7:0]  func_out,
    input  logic [7:0]  func_oe
);
    // Shallow: always route function <-> pads; sel reserved for later
    assign func_in = pad_in;
    assign pad_out = func_out;
    assign pad_oe  = func_oe;

    // Keep sel/clk/rst referenced for lint
    logic unused;
    assign unused = clk ^ rst_n ^ ^sel;
endmodule
