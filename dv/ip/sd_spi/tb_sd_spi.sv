// sd_spi stub testbench — CSR-sideband directed checks
`timescale 1ns / 1ps

module tb_sd_spi;
    logic       clk, rst_n;
    logic       enable, cs_n;
    logic [7:0] data_w, data_r;
    logic       idle, done;
    logic       spi_sclk, spi_mosi, spi_miso, spi_cs_n;
    int fail;

    sd_spi dut (
        .clk(clk), .rst_n(rst_n),
        .enable(enable), .cs_n(cs_n), .data_w(data_w), .data_r(data_r),
        .idle(idle), .done(done),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_cs_n(spi_cs_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) disable iff (!rst_n) idle == 1'b1);

    initial begin
        fail = 0;
        rst_n = 0; enable = 0; cs_n = 1; data_w = 8'h00; spi_miso = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        if (!idle || data_r !== 8'h00) begin
            $error("unexpected reset state");
            fail = 1;
        end

        enable = 1; cs_n = 0; data_w = 8'h80; spi_miso = 1;
        repeat (3) @(posedge clk);
        if (spi_cs_n !== 1'b0) begin
            $error("cs_n not asserted");
            fail = 1;
        end
        if (spi_mosi !== 1'b1) begin
            $error("mosi MSB mismatch");
            fail = 1;
        end
        if (data_r !== 8'hDF) begin
            $error("deterministic data_r expected 0xDF got %h", data_r);
            fail = 1;
        end
        if (!done) begin
            $error("done expected when selected");
            fail = 1;
        end

        enable = 0;
        repeat (2) @(posedge clk);
        if (spi_cs_n !== 1'b1) begin
            $error("cs_n should deassert when disabled");
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("SD_SPI_PASS");
        $finish;
    end
endmodule
