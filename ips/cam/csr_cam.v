// Camera CSR block — Wishbone slave for cam registers (SystemRDL: include/cam_csr.rdl)
`timescale 1ns / 1ps
`include "regs_defines.vh"

module csr_cam (
    input  logic        clk,
    input  logic        rst_n,

    // Wishbone slave (strobed only when this block is selected)
    input  logic        wb_cyc,
    input  logic        wb_stb,
    input  logic        wb_we,
    input  logic [3:0]  wb_sel,
    input  logic [31:0] wb_adr,
    input  logic [31:0] wb_dat_w,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,

    // Hardware sideband
    output logic        cam_enable,
    output logic [15:0] cam_frame_w,
    output logic [15:0] cam_frame_h,
    input  logic        cam_busy,
    input  logic        cam_frame_done
);
    // Relative offsets within cam base (0x1000_0000)
    localparam logic [7:0] OFF_CTRL    = 8'h00;
    localparam logic [7:0] OFF_STATUS  = 8'h04;
    localparam logic [7:0] OFF_FRAME_W = 8'h08;
    localparam logic [7:0] OFF_FRAME_H = 8'h0C;

    logic [31:0] cam_ctrl;
    logic [31:0] cam_frame_w_r;
    logic [31:0] cam_frame_h_r;

    logic        req;
    logic [7:0]  off;

    assign req = wb_cyc & wb_stb;
    assign off = wb_adr[7:0];

    // Silence unused byte-enables / upper address bits
    wire unused_cam_if = |wb_sel | |wb_adr[31:8];

    assign cam_enable  = cam_ctrl[0];
    assign cam_frame_w = cam_frame_w_r[15:0];
    assign cam_frame_h = cam_frame_h_r[15:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cam_ctrl      <= 32'h0;
            cam_frame_w_r <= 32'h4;
            cam_frame_h_r <= 32'h4;
            wb_ack        <= 1'b0;
            wb_dat_r      <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (req && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    unique case (off)
                        OFF_CTRL:    cam_ctrl      <= wb_dat_w;
                        OFF_FRAME_W: cam_frame_w_r <= wb_dat_w;
                        OFF_FRAME_H: cam_frame_h_r <= wb_dat_w;
                        default: ;
                    endcase
                end else begin
                    unique case (off)
                        OFF_CTRL:    wb_dat_r <= cam_ctrl;
                        OFF_STATUS:  wb_dat_r <= {30'h0, cam_frame_done, cam_busy};
                        OFF_FRAME_W: wb_dat_r <= cam_frame_w_r;
                        OFF_FRAME_H: wb_dat_r <= cam_frame_h_r;
                        default:     wb_dat_r <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
