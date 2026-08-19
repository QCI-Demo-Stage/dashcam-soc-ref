// Reusable Wishbone B4 peripheral stub template.
// Used by IP-level verification of lightweight peripheral CSR slaves.
// Returns a programmable constant on reads (default 0xDEAD_BEEF).
`timescale 1ns / 1ps

module wb_periph_stub #(
    parameter logic [31:0] READ_VALUE = 32'hDEAD_BEEF,
    parameter logic [31:0] RESET_CTRL = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        wb_cyc,
    input  logic        wb_stb,
    input  logic        wb_we,
    input  logic [3:0]  wb_sel,
    input  logic [31:0] wb_adr,
    input  logic [31:0] wb_dat_w,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,

    // Exposed CTRL mirror for integration checks
    output logic [31:0] ctrl_reg
);
    logic        req;
    logic [31:0] ctrl;

    assign req      = wb_cyc & wb_stb;
    assign ctrl_reg = ctrl;

    // Tie off unused Wishbone address MSBs and byte enables for lint hygiene
    wire unused_wb = ^{wb_sel, wb_adr[31:4]};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl     <= RESET_CTRL;
            wb_ack   <= 1'b0;
            wb_dat_r <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    // Offset 0x0 = CTRL
                    if (wb_adr[3:0] == 4'h0)
                        ctrl <= wb_dat_w;
                end else begin
                    unique case (wb_adr[3:0])
                        4'h0:    wb_dat_r <= ctrl;
                        4'h4:    wb_dat_r <= READ_VALUE;
                        default: wb_dat_r <= READ_VALUE;
                    endcase
                end
            end
        end
    end
endmodule
