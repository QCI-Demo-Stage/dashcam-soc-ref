// Reset synchronizer (stub — interface-complete)
// Active-low async reset in, synchronized active-low reset out.
`timescale 1ns / 1ps

module rst_sync (
    input  logic clk,
    input  logic rst_n_async,
    output logic rst_n
);
    logic r0, r1;

    always_ff @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            r0   <= 1'b0;
            r1   <= 1'b0;
        end else begin
            r0   <= 1'b1;
            r1   <= r0;
        end
    end

    assign rst_n = r1;
endmodule
