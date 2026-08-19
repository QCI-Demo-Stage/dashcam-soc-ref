// SD-SPI peripheral stub — deterministic idle controller with registered pads.
// CSR fields live in soc_csr (SDSPI_CTRL / STATUS / DATA); this block consumes
// the sideband control wires and presents fixed stub SPI behavior.
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
    logic       enable_q;
    logic       cs_n_q;
    logic [7:0] data_w_q;
    logic       miso_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_q  <= 1'b0;
            cs_n_q    <= 1'b1;
            data_w_q  <= 8'h00;
            miso_q    <= 1'b0;
            data_r    <= 8'h00;
            idle      <= 1'b1;
            done      <= 1'b0;
            spi_sclk  <= 1'b0;
            spi_mosi  <= 1'b0;
            spi_cs_n  <= 1'b1;
        end else begin
            enable_q <= enable;
            cs_n_q   <= cs_n;
            data_w_q <= data_w;
            miso_q   <= spi_miso;

            idle     <= 1'b1;
            done     <= enable_q & ~cs_n_q;
            // Stub clock: hold low; fold data_w parity into unused sclk path
            spi_sclk <= 1'b0 & (^data_w_q);
            spi_mosi <= data_w_q[7];
            spi_cs_n <= cs_n_q | ~enable_q;
            // Deterministic read: 0xDE/0xDF with MISO in LSB when enabled
            data_r   <= enable_q ? {7'h6F, miso_q} : 8'h00;
        end
    end
endmodule
