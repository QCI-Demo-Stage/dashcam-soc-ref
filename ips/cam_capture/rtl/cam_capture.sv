// Camera capture — Wishbone-controlled via soc_csr sideband.
// Captures an 8-bit RGB byte stream (R,G,B repeating), packs RGB888,
// and presents pixels through a small sync FIFO to the DMA engine.
`timescale 1ns / 1ps

module cam_capture #(
    parameter int FIFO_DEPTH = 8
) (
    input  logic        clk,
    input  logic        rst_n,

    // Control from CSR (soc_csr CAM_* registers)
    input  logic        enable,
    input  logic [15:0] frame_w,
    input  logic [15:0] frame_h,
    output logic        busy,
    output logic        frame_done,

    // Camera pad interface (same clock domain as clk for this SoC)
    input  logic        cam_vsync,
    input  logic        cam_href,
    input  logic [7:0]  cam_data,
    input  logic        cam_pclk_valid,

    // Pixel stream to DMA (RGB888)
    output logic        pix_valid,
    output logic [23:0] pix_rgb,
    input  logic        pix_ready
);
    // -------------------------------------------------------------------------
    // Capture / packing state
    // -------------------------------------------------------------------------
    logic [15:0] x_cnt;
    logic [15:0] y_cnt;
    logic        in_frame;
    logic [1:0]  byte_idx;
    logic [23:0] pix_shift;
    logic        done_sticky;
    logic        fifo_overflow;

    // -------------------------------------------------------------------------
    // Sync FIFO (pixel buffer)
    // -------------------------------------------------------------------------
    localparam int PTR_W = $clog2(FIFO_DEPTH);

    logic [23:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_W:0] wr_ptr;
    logic [PTR_W:0] rd_ptr;
    logic [PTR_W:0] count;

    logic        fifo_full;
    logic        fifo_empty;
    logic        fifo_push;
    logic        fifo_pop;
    logic [23:0] fifo_din;

    assign fifo_full  = (count == FIFO_DEPTH[PTR_W:0]);
    assign fifo_empty = (count == '0);
    assign fifo_pop   = pix_valid && pix_ready;

    assign pix_valid = enable && !fifo_empty;
    assign pix_rgb   = fifo_mem[rd_ptr[PTR_W-1:0]];

    assign busy       = in_frame || !fifo_empty;
    assign frame_done = done_sticky;

    // Pack complete pixel when third byte arrives and FIFO has room
    logic accept_byte;
    assign accept_byte = enable && in_frame && cam_href && cam_pclk_valid && !fifo_full;

    always_comb begin
        fifo_push = 1'b0;
        fifo_din  = pix_shift;
        if (accept_byte && byte_idx == 2'd2) begin
            fifo_push = 1'b1;
            fifo_din  = {pix_shift[23:8], cam_data};
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt         <= 16'h0;
            y_cnt         <= 16'h0;
            in_frame      <= 1'b0;
            byte_idx      <= 2'h0;
            pix_shift     <= 24'h0;
            done_sticky   <= 1'b0;
            fifo_overflow <= 1'b0;
            wr_ptr        <= '0;
            rd_ptr        <= '0;
            count         <= '0;
        end else begin
            if (!enable) begin
                x_cnt         <= 16'h0;
                y_cnt         <= 16'h0;
                in_frame      <= 1'b0;
                byte_idx      <= 2'h0;
                pix_shift     <= 24'h0;
                done_sticky   <= 1'b0;
                fifo_overflow <= 1'b0;
                wr_ptr        <= '0;
                rd_ptr        <= '0;
                count         <= '0;
            end else begin
                // FIFO push/pop accounting
                unique case ({fifo_push, fifo_pop})
                    2'b10: begin
                        fifo_mem[wr_ptr[PTR_W-1:0]] <= fifo_din;
                        wr_ptr <= wr_ptr + 1'b1;
                        count  <= count + 1'b1;
                    end
                    2'b01: begin
                        rd_ptr <= rd_ptr + 1'b1;
                        count  <= count - 1'b1;
                    end
                    2'b11: begin
                        fifo_mem[wr_ptr[PTR_W-1:0]] <= fifo_din;
                        wr_ptr <= wr_ptr + 1'b1;
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                    default: ;
                endcase

                // Overflow sticky (byte dropped because FIFO full)
                if (in_frame && cam_href && cam_pclk_valid && fifo_full)
                    fifo_overflow <= 1'b1;

                if (cam_vsync) begin
                    in_frame    <= 1'b1;
                    x_cnt       <= 16'h0;
                    y_cnt       <= 16'h0;
                    byte_idx    <= 2'h0;
                    done_sticky <= 1'b0;
                end else if (accept_byte) begin
                    unique case (byte_idx)
                        2'd0: begin
                            pix_shift[23:16] <= cam_data;
                            byte_idx <= 2'd1;
                        end
                        2'd1: begin
                            pix_shift[15:8] <= cam_data;
                            byte_idx <= 2'd2;
                        end
                        default: begin
                            pix_shift[7:0] <= cam_data;
                            byte_idx <= 2'd0;
                            if (x_cnt + 16'd1 >= frame_w) begin
                                x_cnt <= 16'h0;
                                if (y_cnt + 16'd1 >= frame_h) begin
                                    in_frame    <= 1'b0;
                                    done_sticky <= 1'b1;
                                    y_cnt       <= 16'h0;
                                end else begin
                                    y_cnt <= y_cnt + 16'd1;
                                end
                            end else begin
                                x_cnt <= x_cnt + 16'd1;
                            end
                        end
                    endcase
                end
            end
        end
    end

    // Keep overflow visible to lint / future STATUS bit without changing ports
    wire unused_ovf = fifo_overflow;
endmodule
