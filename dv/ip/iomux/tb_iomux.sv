// iomux stub testbench
`timescale 1ns / 1ps

module tb_iomux;
    logic        clk, rst_n;
    logic [3:0]  sel;
    logic [7:0]  pad_in, pad_out, pad_oe;
    logic [7:0]  func_in, func_out, func_oe;
    int fail;

    iomux dut (
        .clk(clk), .rst_n(rst_n), .sel(sel),
        .pad_in(pad_in), .pad_out(pad_out), .pad_oe(pad_oe),
        .func_in(func_in), .func_out(func_out), .func_oe(func_oe)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        fail = 0;
        rst_n = 0; sel = 0; pad_in = 8'h55; func_out = 8'hAA; func_oe = 8'h0F;
        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        if (func_in !== 8'h55 || pad_out !== 8'hAA || pad_oe !== 8'h0F) begin
            $error("sel0 passthrough fail fi=%h po=%h oe=%h", func_in, pad_out, pad_oe);
            fail = 1;
        end

        sel = 4'hA;
        pad_in = 8'hFF;
        repeat (3) @(posedge clk);
        if (func_in !== (8'hFF & {4'hF, 4'hA})) begin
            $error("sel mask fail %h", func_in);
            fail = 1;
        end
        if (pad_oe !== (8'h0F | {4'h0, 4'hA})) begin
            $error("oe merge fail %h", pad_oe);
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("IOMUX_PASS");
        $finish;
    end
endmodule
