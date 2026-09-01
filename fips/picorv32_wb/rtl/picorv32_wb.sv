// picoRV32 Wishbone master stub — interface-complete placeholder.
// Fabric IP (fips/): when USE_CPU=1 the top selects this master; stub holds
// the bus idle until a real picoRV32 core is integrated.
`timescale 1ns / 1ps

module picorv32_wb #(
    parameter int AW = 32,
    parameter int DW = 32
) (
    input  logic            clk,
    input  logic            rst_n,
    input  logic            irq,

    // Wishbone B4 master
    output logic            wb_cyc,
    output logic            wb_stb,
    output logic            wb_we,
    output logic [3:0]      wb_sel,
    output logic [AW-1:0]   wb_adr,
    output logic [DW-1:0]   wb_dat_w,
    input  logic [DW-1:0]   wb_dat_r,
    input  logic            wb_ack
);
    // -------------------------------------------------------------------------
    // Placeholder: future picoRV32 + Wishbone adapter lands here.
    // -------------------------------------------------------------------------
    logic unused_irq;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_cyc     <= 1'b0;
            wb_stb     <= 1'b0;
            wb_we      <= 1'b0;
            wb_sel     <= 4'h0;
            wb_adr     <= {AW{1'b0}};
            wb_dat_w   <= {DW{1'b0}};
            unused_irq <= 1'b0;
        end else begin
            // Stub policy: never assert the bus.
            wb_cyc     <= 1'b0;
            wb_stb     <= 1'b0;
            wb_we      <= 1'b0;
            wb_sel     <= 4'h0;
            wb_adr     <= {AW{1'b0}};
            wb_dat_w   <= {DW{1'b0}};
            unused_irq <= irq ^ wb_ack ^ ^wb_dat_r;
        end
    end
endmodule
