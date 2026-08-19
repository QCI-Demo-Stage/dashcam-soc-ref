// SD-SPI controller stub — interface-complete, idle/ready behavior
`timescale 1ns / 1ps

module sd_spi (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       enable,
    input  logic       cs_n,
    input  logic [7:0] data_w,
    output logic [7:0] data_r,
    output logic       idle,
    output logic       done,

    // SPI pads
    output logic       spi_sclk,
    output logic       spi_mosi,
    input  logic       spi_miso,
    output logic       spi_cs_n
);
    assign spi_cs_n = cs_n | ~enable;
    assign spi_sclk = 1'b0;
    assign spi_mosi = data_w[7];
    assign data_r   = {7'h0, spi_miso};
    assign idle     = 1'b1;
    assign done     = 1'b0;

    wire unused = clk ^ rst_n ^ ^data_w[6:0];
endmodule
