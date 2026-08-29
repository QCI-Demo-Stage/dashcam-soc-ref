// Wishbone B4 interconnect stub (fabric IP).
// Routes one master to CSR (0x1000_0000) and SRAM (0x2000_0000) slaves.
// Placeholder for future multi-master / decode-table expansion.
`timescale 1ns / 1ps

module wb_interconnect #(
    parameter int AW = 32,
    parameter int DW = 32
) (
    input  logic            clk,
    input  logic            rst_n,

    // Master
    input  logic            m_cyc,
    input  logic            m_stb,
    input  logic            m_we,
    input  logic [3:0]      m_sel,
    input  logic [AW-1:0]   m_adr,
    input  logic [DW-1:0]   m_dat_w,
    output logic [DW-1:0]   m_dat_r,
    output logic            m_ack,

    // CSR slave @ 0x1000_0000
    output logic            s0_cyc,
    output logic            s0_stb,
    output logic            s0_we,
    output logic [3:0]      s0_sel,
    output logic [AW-1:0]   s0_adr,
    output logic [DW-1:0]   s0_dat_w,
    input  logic [DW-1:0]   s0_dat_r,
    input  logic            s0_ack,

    // SRAM slave @ 0x2000_0000
    output logic            s1_cyc,
    output logic            s1_stb,
    output logic            s1_we,
    output logic [3:0]      s1_sel,
    output logic [AW-1:0]   s1_adr,
    output logic [DW-1:0]   s1_dat_w,
    input  logic [DW-1:0]   s1_dat_r,
    input  logic            s1_ack
);
    logic sel_csr;
    logic sel_sram;
    // Reserved fabric state for a future registered decode / arbiter
    logic fabric_idle_q;

    // -------------------------------------------------------------------------
    // Window decode (placeholder for a programmable decode table)
    // -------------------------------------------------------------------------
    assign sel_csr  = (m_adr[AW-1:AW-4] == 4'h1);
    assign sel_sram = (m_adr[AW-1:AW-4] == 4'h2);

    assign s0_cyc   = m_cyc & sel_csr;
    assign s0_stb   = m_stb & sel_csr;
    assign s0_we    = m_we;
    assign s0_sel   = m_sel;
    assign s0_adr   = m_adr;
    assign s0_dat_w = m_dat_w;

    assign s1_cyc   = m_cyc & sel_sram;
    assign s1_stb   = m_stb & sel_sram;
    assign s1_we    = m_we;
    assign s1_sel   = m_sel;
    assign s1_adr   = m_adr;
    assign s1_dat_w = m_dat_w;

    assign m_dat_r = sel_csr ? s0_dat_r : (sel_sram ? s1_dat_r : {DW{1'b0}});
    assign m_ack   = (sel_csr & s0_ack) | (sel_sram & s1_ack);

    // Placeholder always block — reserved for registered fabric / fairness
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fabric_idle_q <= 1'b1;
        end else begin
            // Future: optional registered decode / multi-master arbiter
            fabric_idle_q <= ~(m_cyc & m_stb);
        end
    end

    wire unused_fabric = fabric_idle_q;
endmodule
