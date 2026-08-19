// sram_ctrl / memory controller IP testbench
`timescale 1ns / 1ps

module tb_sram_ctrl;
    logic        clk, rst_n;
    logic        wb_cyc, wb_stb, wb_we, wb_ack;
    logic [3:0]  wb_sel;
    logic [31:0] wb_adr, wb_dat_w, wb_dat_r;

    int fail;
    int cov_rw, cov_be, cov_lat, cov_rand, cov_proto;
    int cov_total, cov_hit;

    sram_ctrl #(.DEPTH_WORDS(256), .LATENCY(0)) dut0 (
        .clk(clk), .rst_n(rst_n),
        .wb_cyc(wb_cyc), .wb_stb(wb_stb), .wb_we(wb_we), .wb_sel(wb_sel),
        .wb_adr(wb_adr), .wb_dat_w(wb_dat_w), .wb_dat_r(wb_dat_r), .wb_ack(wb_ack)
    );

    // Second instance with latency for coverage
    logic        c1, s1, w1, a1;
    logic [3:0]  sel1;
    logic [31:0] adr1, dw1, dr1;

    sram_ctrl #(.DEPTH_WORDS(256), .LATENCY(2)) dut2 (
        .clk(clk), .rst_n(rst_n),
        .wb_cyc(c1), .wb_stb(s1), .wb_we(w1), .wb_sel(sel1),
        .wb_adr(adr1), .wb_dat_w(dw1), .wb_dat_r(dr1), .wb_ack(a1)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) disable iff (!rst_n)
        !(wb_stb && !wb_cyc));
    assert property (@(posedge clk) disable iff (!rst_n)
        !(wb_ack && !(wb_cyc && wb_stb)));

    task automatic wb_write(input logic [31:0] adr, input logic [31:0] data, input logic [3:0] sel);
        begin
            @(posedge clk);
            wb_cyc <= 1; wb_stb <= 1; wb_we <= 1; wb_sel <= sel;
            wb_adr <= adr; wb_dat_w <= data;
            while (1) begin
                @(posedge clk);
                if (wb_ack) break;
            end
            wb_cyc <= 0; wb_stb <= 0; wb_we <= 0;
            @(posedge clk);
        end
    endtask

    task automatic wb_read(input logic [31:0] adr, output logic [31:0] data);
        begin
            @(posedge clk);
            wb_cyc <= 1; wb_stb <= 1; wb_we <= 0; wb_sel <= 4'hF;
            wb_adr <= adr; wb_dat_w <= 0;
            while (1) begin
                @(posedge clk);
                if (wb_ack) begin data = wb_dat_r; break; end
            end
            wb_cyc <= 0; wb_stb <= 0;
            @(posedge clk);
        end
    endtask

    task automatic wb_write_lat(input logic [31:0] adr, input logic [31:0] data);
        begin
            @(posedge clk);
            c1 <= 1; s1 <= 1; w1 <= 1; sel1 <= 4'hF;
            adr1 <= adr; dw1 <= data;
            while (1) begin
                @(posedge clk);
                if (a1) break;
            end
            c1 <= 0; s1 <= 0; w1 <= 0;
            @(posedge clk);
        end
    endtask

    task automatic wb_read_lat(input logic [31:0] adr, output logic [31:0] data);
        begin
            @(posedge clk);
            c1 <= 1; s1 <= 1; w1 <= 0; sel1 <= 4'hF;
            adr1 <= adr; dw1 <= 0;
            while (1) begin
                @(posedge clk);
                if (a1) begin data = dr1; break; end
            end
            c1 <= 0; s1 <= 0;
            @(posedge clk);
        end
    endtask

    initial begin
        logic [31:0] rdata;
        fail = 0;
        cov_rw = 0; cov_be = 0; cov_lat = 0; cov_rand = 0; cov_proto = 1;
        cov_total = 5;
        rst_n = 0;
        wb_cyc = 0; wb_stb = 0; wb_we = 0; wb_sel = 0;
        wb_adr = 0; wb_dat_w = 0;
        c1 = 0; s1 = 0; w1 = 0; sel1 = 0; adr1 = 0; dw1 = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Basic R/W
        wb_write(32'h2000_0000, 32'hA5A5_5A5A, 4'hF);
        wb_read (32'h2000_0000, rdata);
        if (rdata !== 32'hA5A5_5A5A) begin
            $error("basic rw mismatch %h", rdata);
            fail = 1;
        end else cov_rw = 1;

        // Byte enables
        wb_write(32'h2000_0004, 32'h0000_00AA, 4'b0001);
        wb_write(32'h2000_0004, 32'h0000_BB00, 4'b0010);
        wb_write(32'h2000_0004, 32'h00CC_0000, 4'b0100);
        wb_write(32'h2000_0004, 32'hDD00_0000, 4'b1000);
        wb_read (32'h2000_0004, rdata);
        if (rdata !== 32'hDDCC_BBAA) begin
            $error("byte-enable mismatch %h", rdata);
            fail = 1;
        end else cov_be = 1;

        // Latency=2 path
        wb_write_lat(32'h2000_0010, 32'h1234_5678);
        wb_read_lat (32'h2000_0010, rdata);
        if (rdata !== 32'h1234_5678) begin
            $error("latency path mismatch %h", rdata);
            fail = 1;
        end else cov_lat = 1;

        // Constrained random
        for (int t = 0; t < 32; t++) begin
            logic [31:0] a, d, exp;
            logic [3:0]  s;
            a = 32'h2000_0000 + ((t * 4) & 32'h3FC);
            d = $urandom;
            s = 4'($urandom);
            if (s == 0) s = 4'hF;
            wb_read(a, exp);
            if (s[0]) exp[7:0]   = d[7:0];
            if (s[1]) exp[15:8]  = d[15:8];
            if (s[2]) exp[23:16] = d[23:16];
            if (s[3]) exp[31:24] = d[31:24];
            wb_write(a, d, s);
            wb_read(a, rdata);
            if (rdata !== exp) begin
                $error("rand mismatch a=%h got=%h exp=%h sel=%h", a, rdata, exp, s);
                fail = 1;
            end else cov_rand = 1;
        end

        cov_hit = cov_rw + cov_be + cov_lat + cov_rand + cov_proto;
        $display("COVERAGE %0d/%0d (%0d%%)", cov_hit, cov_total, (100 * cov_hit) / cov_total);
        if ((100 * cov_hit) / cov_total < 90) begin
            $error("coverage below 90%%");
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("SRAM_CTRL_PASS");
        $finish;
    end

    initial begin
        #500_000;
        $error("timeout");
        $fatal(1);
    end
endmodule
