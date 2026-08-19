// dma_engine IP testbench — source/sink models, integrity, IRQ/done, coverage
`timescale 1ns / 1ps

module tb_dma_engine;
    logic        clk, rst_n;
    logic        enable;
    logic [31:0] dst_addr, length;
    logic        busy, done;
    logic        pix_valid, pix_ready;
    logic [23:0] pix_rgb;
    logic        wb_cyc, wb_stb, wb_we, wb_ack;
    logic [3:0]  wb_sel;
    logic [31:0] wb_adr, wb_dat_w, wb_dat_r;

    logic [31:0] sram [0:255];
    logic [23:0] src_q [$];
    int fail;
    int cov_start, cov_stop, cov_burst, cov_irq, cov_match;
    int cov_total, cov_hit;

    dma_engine #(.FIFO_DEPTH(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .enable(enable), .dst_addr(dst_addr), .length(length),
        .busy(busy), .done(done),
        .pix_valid(pix_valid), .pix_rgb(pix_rgb), .pix_ready(pix_ready),
        .wb_cyc(wb_cyc), .wb_stb(wb_stb), .wb_we(wb_we), .wb_sel(wb_sel),
        .wb_adr(wb_adr), .wb_dat_w(wb_dat_w), .wb_dat_r(wb_dat_r), .wb_ack(wb_ack)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Simple SRAM slave model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack   <= 1'b0;
            wb_dat_r <= 32'h0;
        end else begin
            wb_ack <= 1'b0;
            if (wb_cyc && wb_stb && !wb_ack) begin
                wb_ack <= 1'b1;
                if (wb_we) begin
                    sram[wb_adr[9:2]] <= wb_dat_w;
                end else begin
                    wb_dat_r <= sram[wb_adr[9:2]];
                end
            end
        end
    end

    // Protocol asserts
    assert property (@(posedge clk) disable iff (!rst_n)
        !(wb_stb && !wb_cyc));
    assert property (@(posedge clk) disable iff (!rst_n)
        !(done && busy));

    task automatic feed_pixels(input int n);
        int k;
        begin
            for (k = 0; k < n; k++) begin
                logic [23:0] p;
                p = {8'(8'hA0+k), 8'(8'hB0+k), 8'(8'hC0+k)};
                src_q.push_back(p);
                @(posedge clk);
                while (!pix_ready) @(posedge clk);
                pix_valid <= 1'b1;
                pix_rgb   <= p;
                @(posedge clk);
                pix_valid <= 1'b0;
            end
        end
    endtask

    task automatic run_xfer(input int npix, input logic [31:0] base);
        int guard;
        begin
            dst_addr = base;
            length   = npix * 4;
            enable   = 1;
            cov_start = 1;
            cov_burst = 1;
            fork
                feed_pixels(npix);
                begin
                    guard = 0;
                    while (!done && guard < 5000) begin
                        @(posedge clk);
                        guard++;
                    end
                end
            join
            if (!done) begin
                $error("DMA timeout");
                fail = 1;
            end else cov_irq = 1;

            for (int k = 0; k < npix; k++) begin
                logic [23:0] exp;
                logic [31:0] got;
                exp = src_q[k];
                got = sram[base[9:2] + k];
                if (got !== {8'h00, exp}) begin
                    $error("mismatch idx %0d got %h exp %h", k, got, {8'h00, exp});
                    fail = 1;
                end else cov_match = 1;
            end
            enable = 0;
            @(posedge clk);
            cov_stop = 1;
            src_q.delete();
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        fail = 0;
        cov_start = 0; cov_stop = 0; cov_burst = 0; cov_irq = 0; cov_match = 0;
        cov_total = 5;
        rst_n = 0; enable = 0; dst_addr = 32'h2000_0000; length = 0;
        pix_valid = 0; pix_rgb = 0;
        for (int z = 0; z < 256; z++) sram[z] = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Directed reset / start / stop
        if (busy || done) begin
            $error("not idle after reset");
            fail = 1;
        end

        run_xfer(4, 32'h2000_0000);

        // Random burst lengths
        for (int t = 0; t < 6; t++) begin
            int n;
            n = 1 + ($urandom % 8);
            run_xfer(n, 32'h2000_0000 + (t * 64));
        end

        // Error handling: disable mid-transfer
        dst_addr = 32'h2000_0100;
        length   = 32;
        enable   = 1;
        @(posedge clk);
        pix_valid <= 1; pix_rgb <= 24'h112233;
        @(posedge clk);
        pix_valid <= 0;
        enable = 0;
        repeat (5) @(posedge clk);
        if (busy) begin
            $error("busy after stop");
            fail = 1;
        end

        cov_hit = cov_start + cov_stop + cov_burst + cov_irq + cov_match;
        $display("COVERAGE %0d/%0d (%0d%%)", cov_hit, cov_total, (100 * cov_hit) / cov_total);
        if ((100 * cov_hit) / cov_total < 90) begin
            $error("coverage below 90%%");
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("DMA_ENGINE_PASS");
        $finish;
    end

    initial begin
        #1_000_000;
        $error("timeout");
        $fatal(1);
    end
endmodule
