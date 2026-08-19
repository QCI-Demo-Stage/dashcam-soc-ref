// wb_periph_stub template testbench — three named CSR variants
`timescale 1ns / 1ps

module tb_wb_periph_stub;
    logic        clk, rst_n;
    logic        cyc, stb, we, ack;
    logic [3:0]  sel;
    logic [31:0] adr, dat_w, dat_r;
    logic [31:0] ctrl_sd, ctrl_io, ctrl_rst;
    int fail;

    // Three template instances with distinct CSR identities
    logic        c0, s0, w0, a0;
    logic [31:0] adr0, dw0, dr0;
    logic        c1, s1, w1, a1;
    logic [31:0] adr1, dw1, dr1;
    logic        c2, s2, w2, a2;
    logic [31:0] adr2, dw2, dr2;

    wb_periph_stub #(.READ_VALUE(32'hDEAD_BEEF), .RESET_CTRL(32'h0)) u_sd_spi_ctrl (
        .clk(clk), .rst_n(rst_n),
        .wb_cyc(c0), .wb_stb(s0), .wb_we(w0), .wb_sel(sel),
        .wb_adr(adr0), .wb_dat_w(dw0), .wb_dat_r(dr0), .wb_ack(a0),
        .ctrl_reg(ctrl_sd)
    );

    wb_periph_stub #(.READ_VALUE(32'hDEAD_BEEF), .RESET_CTRL(32'h0)) u_iomux_cfg (
        .clk(clk), .rst_n(rst_n),
        .wb_cyc(c1), .wb_stb(s1), .wb_we(w1), .wb_sel(sel),
        .wb_adr(adr1), .wb_dat_w(dw1), .wb_dat_r(dr1), .wb_ack(a1),
        .ctrl_reg(ctrl_io)
    );

    wb_periph_stub #(.READ_VALUE(32'hDEAD_BEEF), .RESET_CTRL(32'h1)) u_reset_sync (
        .clk(clk), .rst_n(rst_n),
        .wb_cyc(c2), .wb_stb(s2), .wb_we(w2), .wb_sel(sel),
        .wb_adr(adr2), .wb_dat_w(dw2), .wb_dat_r(dr2), .wb_ack(a2),
        .ctrl_reg(ctrl_rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic wr0(input logic [31:0] a, input logic [31:0] d);
        begin
            @(posedge clk);
            c0 <= 1; s0 <= 1; w0 <= 1; adr0 <= a; dw0 <= d; sel <= 4'hF;
            while (1) begin @(posedge clk); if (a0) break; end
            c0 <= 0; s0 <= 0; w0 <= 0; @(posedge clk);
        end
    endtask

    task automatic rd0(input logic [31:0] a, output logic [31:0] d);
        begin
            @(posedge clk);
            c0 <= 1; s0 <= 1; w0 <= 0; adr0 <= a; dw0 <= 0; sel <= 4'hF;
            while (1) begin @(posedge clk); if (a0) begin d = dr0; break; end end
            c0 <= 0; s0 <= 0; @(posedge clk);
        end
    endtask

    task automatic rd1(input logic [31:0] a, output logic [31:0] d);
        begin
            @(posedge clk);
            c1 <= 1; s1 <= 1; w1 <= 0; adr1 <= a; dw1 <= 0; sel <= 4'hF;
            while (1) begin @(posedge clk); if (a1) begin d = dr1; break; end end
            c1 <= 0; s1 <= 0; @(posedge clk);
        end
    endtask

    task automatic rd2(input logic [31:0] a, output logic [31:0] d);
        begin
            @(posedge clk);
            c2 <= 1; s2 <= 1; w2 <= 0; adr2 <= a; dw2 <= 0; sel <= 4'hF;
            while (1) begin @(posedge clk); if (a2) begin d = dr2; break; end end
            c2 <= 0; s2 <= 0; @(posedge clk);
        end
    endtask

    initial begin
        logic [31:0] d;
        fail = 0;
        rst_n = 0;
        c0 = 0; s0 = 0; w0 = 0; adr0 = 0; dw0 = 0;
        c1 = 0; s1 = 0; w1 = 0; adr1 = 0; dw1 = 0;
        c2 = 0; s2 = 0; w2 = 0; adr2 = 0; dw2 = 0;
        sel = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // STATUS-like offset returns DEADBEEF
        rd0(32'h4, d);
        assert (d === 32'hDEAD_BEEF) else begin $error("sd stub read"); fail = 1; end
        rd1(32'h4, d);
        assert (d === 32'hDEAD_BEEF) else begin $error("iomux stub read"); fail = 1; end
        rd2(32'h4, d);
        assert (d === 32'hDEAD_BEEF) else begin $error("rst stub read"); fail = 1; end

        // CTRL write/read
        wr0(32'h0, 32'h0000_0003);
        rd0(32'h0, d);
        assert (d === 32'h0000_0003) else begin $error("sd ctrl"); fail = 1; end
        assert (ctrl_sd === 32'h3) else begin $error("ctrl mirror"); fail = 1; end

        // RESET_SYNC default CTRL reset value
        rd2(32'h0, d);
        assert (d === 32'h1) else begin $error("rst ctrl reset %h", d); fail = 1; end

        if (fail) $fatal(1);
        $display("WB_PERIPH_STUB_PASS");
        $finish;
    end
endmodule
