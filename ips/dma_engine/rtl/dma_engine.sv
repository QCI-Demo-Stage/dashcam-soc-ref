// Simple DMA engine — drains camera RGB888 pixels into Wishbone writes to SRAM.
// One pixel -> one 32-bit word write {8'h00, R, G, B} at DST_ADDR advancing by 4.
// Burst length is controlled by LENGTH (bytes); completion sticky drives IRQ path.
`timescale 1ns / 1ps

module dma_engine #(
    parameter int FIFO_DEPTH = 4
) (
    input  logic        clk,
    input  logic        rst_n,

    // Control from CSR (soc_csr DMA_* registers)
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

    localparam int PTR_W = $clog2(FIFO_DEPTH);

    logic [23:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_W:0] wr_ptr;
    logic [PTR_W:0] rd_ptr;
    logic [PTR_W:0] count;

    logic        fifo_full;
    logic        fifo_empty;
    logic [23:0] fifo_dout;

    logic [31:0] wr_addr;
    logic [31:0] bytes_left;
    logic        armed;

    logic        fifo_push;
    logic        fifo_pop;
    logic        start_wr;
    logic        fifo_active;

    assign fifo_full  = (count == FIFO_DEPTH[PTR_W:0]);
    assign fifo_empty = (count == '0);
    assign fifo_dout  = fifo_mem[rd_ptr[PTR_W-1:0]];

    assign busy      = (state == ST_RUN) || (state == ST_WR);
    assign done      = (state == ST_DONE);
    assign wb_we     = 1'b1;
    assign wb_sel    = 4'hF;
    assign pix_ready = enable && ((state == ST_RUN) || (state == ST_WR)) && !fifo_full;

    assign fifo_push   = pix_valid && pix_ready;
    assign start_wr    = (state == ST_RUN) && enable && (bytes_left != 32'h0) && !fifo_empty;
    assign fifo_pop    = start_wr;
    assign fifo_active = enable && (state == ST_RUN || state == ST_WR);

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
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            count      <= '0;
        end else begin
            if (fifo_active) begin
                unique case ({fifo_push, fifo_pop})
                    2'b10: begin
                        fifo_mem[wr_ptr[PTR_W-1:0]] <= pix_rgb;
                        wr_ptr <= wr_ptr + 1'b1;
                        count  <= count + 1'b1;
                    end
                    2'b01: begin
                        rd_ptr <= rd_ptr + 1'b1;
                        count  <= count - 1'b1;
                    end
                    2'b11: begin
                        fifo_mem[wr_ptr[PTR_W-1:0]] <= pix_rgb;
                        wr_ptr <= wr_ptr + 1'b1;
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                    default: ;
                endcase
            end

            unique case (state)
                ST_IDLE: begin
                    wb_cyc <= 1'b0;
                    wb_stb <= 1'b0;
                    if (enable && !armed) begin
                        wr_addr    <= dst_addr;
                        bytes_left <= length;
                        armed      <= 1'b1;
                        wr_ptr     <= '0;
                        rd_ptr     <= '0;
                        count      <= '0;
                        state      <= ST_RUN;
                    end else if (!enable) begin
                        armed <= 1'b0;
                    end
                end
                ST_RUN: begin
                    wb_cyc <= 1'b0;
                    wb_stb <= 1'b0;
                    if (!enable) begin
                        armed  <= 1'b0;
                        wr_ptr <= '0;
                        rd_ptr <= '0;
                        count  <= '0;
                        state  <= ST_IDLE;
                    end else if (bytes_left == 32'h0) begin
                        state <= ST_DONE;
                    end else if (start_wr) begin
                        wb_adr   <= wr_addr;
                        wb_dat_w <= {8'h00, fifo_dout};
                        wb_cyc   <= 1'b1;
                        wb_stb   <= 1'b1;
                        state    <= ST_WR;
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
                        armed  <= 1'b0;
                        wr_ptr <= '0;
                        rd_ptr <= '0;
                        count  <= '0;
                        state  <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
