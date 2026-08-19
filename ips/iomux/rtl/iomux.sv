// IOMUX stub — registered pad mux with selectable function routing.
// CSR field IOMUX_CTRL.SEL is supplied via soc_csr sideband.
`timescale 1ns / 1ps

module iomux (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [3:0]  sel,

    // Pad side
    input  logic [7:0]  pad_in,
    output logic [7:0]  pad_out,
    output logic [7:0]  pad_oe,

    // Function side
    output logic [7:0]  func_in,
    input  logic [7:0]  func_out,
    input  logic [7:0]  func_oe
);
    logic [3:0] sel_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_q   <= 4'h0;
            func_in <= 8'h00;
            pad_out <= 8'h00;
            pad_oe  <= 8'h00;
        end else begin
            sel_q <= sel;
            // sel==0: straight through; nonzero: mask low nibble (stub policy)
            if (sel_q == 4'h0) begin
                func_in <= pad_in;
                pad_out <= func_out;
                pad_oe  <= func_oe;
            end else begin
                func_in <= pad_in & {4'hF, sel_q};
                pad_out <= func_out;
                pad_oe  <= func_oe | {4'h0, sel_q};
            end
        end
    end
endmodule
