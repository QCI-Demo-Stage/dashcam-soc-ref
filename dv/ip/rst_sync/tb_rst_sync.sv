// rst_sync testbench — async assert, sync deassert
`timescale 1ns / 1ps

module tb_rst_sync;
    logic clk, rst_n_async, rst_n;
    int fail;

    rst_sync dut (.clk(clk), .rst_n_async(rst_n_async), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    // Two-flop release: rst_n follows r1
    assert property (@(posedge clk) disable iff (!rst_n_async)
        rst_n == dut.r1);

    initial begin
        fail = 0;
        rst_n_async = 0;
        repeat (4) @(posedge clk);
        if (rst_n !== 1'b0) begin
            $error("rst_n should be low while async asserted");
            fail = 1;
        end

        rst_n_async = 1;
        @(posedge clk);
        // First sync flop may be 1, output still 0
        if (rst_n !== 1'b0) begin
            $error("rst_n released too early");
            fail = 1;
        end
        @(posedge clk);
        @(negedge clk);
        if (rst_n !== 1'b1) begin
            $error("rst_n should be high after 2 flops");
            fail = 1;
        end

        // Re-assert async
        rst_n_async = 0;
        #1;
        if (rst_n !== 1'b0) begin
            $error("async assert failed");
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("RST_SYNC_PASS");
        $finish;
    end
endmodule
