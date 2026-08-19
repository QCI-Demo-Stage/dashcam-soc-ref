// IRQ controller stub
`timescale 1ns / 1ps

module irq_ctrl (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cam_irq,
    input  logic        dma_irq,

    input  logic [31:0] irq_enable,
    input  logic [31:0] pending_clear,
    output logic [31:0] irq_pending,
    output logic        irq_out
);
    logic [31:0] pending;

    assign irq_pending = pending;
    assign irq_out     = |(pending & irq_enable);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending <= 32'h0;
        end else begin
            pending <= (pending | {30'h0, dma_irq, cam_irq}) & ~pending_clear;
        end
    end
endmodule
