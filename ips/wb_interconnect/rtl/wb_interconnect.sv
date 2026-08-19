// Wishbone B4 interconnect stub
// Routes one master to CSR (0x1000_0000) and SRAM (0x2000_0000) slaves.
`timescale 1ns / 1ps

module wb_interconnect (
    input  logic        clk,
    input  logic        rst_n,

    // Master
    input  logic        m_cyc,
    input  logic        m_stb,
    input  logic        m_we,
    input  logic [3:0]  m_sel,
    input  logic [31:0] m_adr,
    input  logic [31:0] m_dat_w,
    output logic [31:0] m_dat_r,
    output logic        m_ack,

    // CSR slave @ 0x1000_0000
    output logic        s0_cyc,
    output logic        s0_stb,
    output logic        s0_we,
    output logic [3:0]  s0_sel,
    output logic [31:0] s0_adr,
    output logic [31:0] s0_dat_w,
    input  logic [31:0] s0_dat_r,
    input  logic        s0_ack,

    // SRAM slave @ 0x2000_0000
    output logic        s1_cyc,
    output logic        s1_stb,
    output logic        s1_we,
    output logic [3:0]  s1_sel,
    output logic [31:0] s1_adr,
    output logic [31:0] s1_dat_w,
    input  logic [31:0] s1_dat_r,
    input  logic        s1_ack
);
    logic sel_csr;
    logic sel_sram;

    // Combinational fabric; keep clk/rst ports for interface stability
    wire unused_clk_rst = clk ^ rst_n;

    assign sel_csr  = (m_adr[31:28] == 4'h1);
    assign sel_sram = (m_adr[31:28] == 4'h2);

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

    assign m_dat_r = sel_csr ? s0_dat_r : (sel_sram ? s1_dat_r : 32'h0);
    assign m_ack   = (sel_csr & s0_ack) | (sel_sram & s1_ack);
endmodule
