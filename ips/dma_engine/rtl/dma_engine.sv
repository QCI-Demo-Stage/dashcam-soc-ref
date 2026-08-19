// DMA engine stub — drains camera pixel stream into Wishbone writes to SRAM.
// One RGB888 pixel -> one 32-bit word write {8'h00, R, G, B}.
`timescale 1ns / 1ps

module dma_engine (
    input  logic        clk,
    input  logic        rst_n,

    // Control
    input  logic        enable,
    input  logic [31:0] dst_addr,
    input  logic [31:0] length,
    output logic        busy,
    output logic        done,

    // Pixel stream from camera
    input  logic        pix_valid,
    input  logic [23:0] pix_rgb,
    output logic        pix_ready,

    // Wishbone master toward interconnect
    output logic        wb_cyc,
    output logic        wb_stb,
    output logic        wb_we,
    output logic [3:0]  wb_sel,
    output logic [31:0] wb_adr,
    output logic [31:0] wb_dat_w,
    input  logic [31:0] wb_dat_r,
    input  logic        wb_ack
);
    typedef enum logic [1:0] {ST_IDLE, ST_RUN, ST_WR, ST_DONE} state_t;
    state_t state;

    logic [31:0] wr_addr;
    logic [31:0] bytes_left;
    logic        armed;

    assign busy      = (state == ST_RUN) || (state == ST_WR);
    assign done      = (state == ST_DONE);
    assign pix_ready = (state == ST_RUN) && !wb_cyc;
    assign wb_we     = 1'b1;
    assign wb_sel    = 4'hF;

    // Silence unused read data
    wire unused_rd = |wb_dat_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            wr_addr    <= 32'h0;
            bytes_left <= 32'h0;
            armed      <= 1'b0;
            wb_cyc     <= 1'b0;
            wb_stb     <= 1'b0;
            wb_adr     <= 32'h0;
            wb_dat_w   <= 32'h0;
        end else begin
            unique case (state)
                ST_IDLE: begin
                    wb_cyc <= 1'b0;
                    wb_stb <= 1'b0;
                    if (enable && !armed) begin
                        wr_addr    <= dst_addr;
                        bytes_left <= length;
                        armed      <= 1'b1;
                        state      <= ST_RUN;
                    end else if (!enable) begin
                        armed <= 1'b0;
                    end
                end
                ST_RUN: begin
                    wb_cyc <= 1'b0;
                    wb_stb <= 1'b0;
                    if (!enable) begin
                        armed <= 1'b0;
                        state <= ST_IDLE;
                    end else if (bytes_left == 32'h0) begin
                        state <= ST_DONE;
                    end else if (pix_valid && pix_ready) begin
                        wb_adr    <= wr_addr;
                        wb_dat_w  <= {8'h00, pix_rgb};
                        wb_cyc    <= 1'b1;
                        wb_stb    <= 1'b1;
                        state     <= ST_WR;
                    end
                end
                ST_WR: begin
                    if (wb_ack) begin
                        wb_cyc <= 1'b0;
                        wb_stb <= 1'b0;
                        wr_addr <= wr_addr + 32'd4;
                        if (bytes_left <= 32'd4) begin
                            bytes_left <= 32'h0;
                            state      <= ST_DONE;
                        end else begin
                            bytes_left <= bytes_left - 32'd4;
                            state      <= ST_RUN;
                        end
                    end
                end
                ST_DONE: begin
                    wb_cyc <= 1'b0;
                    wb_stb <= 1'b0;
                    if (!enable) begin
                        armed <= 1'b0;
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
