// Camera capture stub — interface-complete with shallow pixel passthrough.
// Accepts an 8-bit pixel stream; when enabled, emits RGB888 beats to DMA.
`timescale 1ns / 1ps

module cam_capture (
    input  logic        clk,
    input  logic        rst_n,

    // Control from CSR
    input  logic        enable,
    input  logic [15:0] frame_w,
    input  logic [15:0] frame_h,
    output logic        busy,
    output logic        frame_done,

    // Camera pad interface
    input  logic        cam_vsync,
    input  logic        cam_href,
    input  logic [7:0]  cam_data,
    input  logic        cam_pclk_valid, // 1 = cam_data valid this cycle

    // Pixel stream to DMA (RGB888 packed over 3 beats or one 24-bit word)
    output logic        pix_valid,
    output logic [23:0] pix_rgb,
    input  logic        pix_ready
);
    logic [15:0] x_cnt;
    logic [15:0] y_cnt;
    logic        in_frame;
    logic [1:0]  byte_idx;
    logic [23:0] pix_shift;
    logic        pending;
    logic        done_sticky;

    assign busy       = in_frame | pending;
    assign frame_done = done_sticky;
    assign pix_valid  = pending;
    assign pix_rgb    = pix_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt       <= 16'h0;
            y_cnt       <= 16'h0;
            in_frame    <= 1'b0;
            byte_idx    <= 2'h0;
            pix_shift   <= 24'h0;
            pending     <= 1'b0;
            done_sticky <= 1'b0;
        end else begin
            if (!enable) begin
                x_cnt       <= 16'h0;
                y_cnt       <= 16'h0;
                in_frame    <= 1'b0;
                byte_idx    <= 2'h0;
                pending     <= 1'b0;
                done_sticky <= 1'b0;
            end else begin
                if (pending && pix_ready)
                    pending <= 1'b0;

                if (cam_vsync) begin
                    in_frame    <= 1'b1;
                    x_cnt       <= 16'h0;
                    y_cnt       <= 16'h0;
                    byte_idx    <= 2'h0;
                    done_sticky <= 1'b0;
                end else if (in_frame && cam_href && cam_pclk_valid && !pending) begin
                    // Pack 3 consecutive bytes into RGB888
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
                            pending  <= 1'b1;
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
endmodule
