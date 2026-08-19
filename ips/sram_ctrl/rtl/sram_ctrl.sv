// SRAM / memory controller — Wishbone B4 slave with byte-enables and
// configurable extra wait-state latency (LATENCY / LATENCY_CFG).
// Window base 0x2000_0000 — behavioral array, PDK-free.
`timescale 1ns / 1ps

module sram_ctrl #(
    parameter int DEPTH_WORDS = 1024,
    parameter int LATENCY     = 0   // extra wait states (0 => single-cycle registered ack)
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

    logic [3:0]  wait_cnt;
    logic        active;
    logic        pending_we;
    logic [3:0]  pending_sel;
    logic [31:0] pending_dat;
    logic [9:0]  pending_idx;

    // Soft CTRL/STATUS mirrors for IP docs / TB introspection via hierarchical refs
    logic [3:0]  latency_cfg;
    logic        ctrl_enable;
    logic        status_busy;

    assign req = wb_cyc & wb_stb;
    assign idx = wb_adr[11:2];

    assign status_busy = active;

    wire unused_adr = |wb_adr[1:0] | |wb_adr[31:12];
    wire unused_ctl = ctrl_enable ^ ^latency_cfg ^ status_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack       <= 1'b0;
            wb_dat_r     <= 32'h0;
            wait_cnt     <= 4'h0;
            active       <= 1'b0;
            pending_we   <= 1'b0;
            pending_sel  <= 4'h0;
            pending_dat  <= 32'h0;
            pending_idx  <= 10'h0;
            latency_cfg  <= LATENCY[3:0];
            ctrl_enable  <= 1'b1;
        end else begin
            wb_ack <= 1'b0;

            if (!active) begin
                if (req && !wb_ack && ctrl_enable) begin
                    active      <= 1'b1;
                    pending_we  <= wb_we;
                    pending_sel <= wb_sel;
                    pending_dat <= wb_dat_w;
                    pending_idx <= idx;
                    wait_cnt    <= latency_cfg;
                end
            end else if (wait_cnt != 4'h0) begin
                wait_cnt <= wait_cnt - 4'h1;
            end else begin
                wb_ack <= 1'b1;
                active <= 1'b0;
                if (pending_we) begin
                    if (pending_sel[0]) mem[pending_idx][7:0]   <= pending_dat[7:0];
                    if (pending_sel[1]) mem[pending_idx][15:8]  <= pending_dat[15:8];
                    if (pending_sel[2]) mem[pending_idx][23:16] <= pending_dat[23:16];
                    if (pending_sel[3]) mem[pending_idx][31:24] <= pending_dat[31:24];
                end else begin
                    wb_dat_r <= mem[pending_idx];
                end
            end
        end
    end
endmodule
