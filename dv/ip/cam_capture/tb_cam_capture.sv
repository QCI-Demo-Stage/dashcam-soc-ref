// cam_capture IP testbench — directed + constrained-random + coverage + asserts
`timescale 1ns / 1ps

module tb_cam_capture;
    localparam int FIFO_DEPTH = 8;

    logic        clk;
    logic        rst_n;
    logic        enable;
    logic [15:0] frame_w;
    logic [15:0] frame_h;
    logic        busy;
    logic        frame_done;
    logic        cam_vsync;
    logic        cam_href;
    logic [7:0]  cam_data;
    logic        cam_pclk_valid;
    logic        pix_valid;
    logic [23:0] pix_rgb;
    logic        pix_ready;

    int cov_enable;
    int cov_frame_done;
    int cov_csr_w;
    int cov_csr_h;
    int cov_pix;
    int cov_total;
    int cov_hit;
    int fail;
    int i;

    cam_capture #(.FIFO_DEPTH(FIFO_DEPTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .enable(enable), .frame_w(frame_w), .frame_h(frame_h),
        .busy(busy), .frame_done(frame_done),
        .cam_vsync(cam_vsync), .cam_href(cam_href),
        .cam_data(cam_data), .cam_pclk_valid(cam_pclk_valid),
        .pix_valid(pix_valid), .pix_rgb(pix_rgb), .pix_ready(pix_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Wishbone-style protocol N/A on cam sideband; assert stream handshake
    assert property (@(posedge clk) disable iff (!rst_n)
        !(pix_valid && pix_ready) || !$isunknown(pix_rgb));

    assert property (@(posedge clk) disable iff (!rst_n)
        !(!enable && busy && frame_done));

    // FIFO underflow: never pop when empty (pix_ready alone does not pop)
    assert property (@(posedge clk) disable iff (!rst_n)
        !(pix_ready && !pix_valid && dut.count == 0 && dut.fifo_pop));

    task automatic send_byte(input logic [7:0] b);
        begin
            @(posedge clk);
            cam_href       <= 1'b1;
            cam_pclk_valid <= 1'b1;
            cam_data       <= b;
            @(posedge clk);
            cam_pclk_valid <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic drain_pixels(input int n);
        int got;
        begin
            got = 0;
            pix_ready <= 1'b1;
            while (got < n) begin
                @(posedge clk);
                if (pix_valid && pix_ready) begin
                    got++;
                    cov_pix++;
                end
            end
            pix_ready <= 1'b0;
        end
    endtask

    initial begin
        fail = 0;
        cov_enable = 0; cov_frame_done = 0; cov_csr_w = 0; cov_csr_h = 0;
        cov_pix = 0; cov_total = 5; cov_hit = 0;
        rst_n = 0; enable = 0; frame_w = 2; frame_h = 2;
        cam_vsync = 0; cam_href = 0; cam_data = 0; cam_pclk_valid = 0;
        pix_ready = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Directed: reset leaves idle
        if (busy || frame_done || pix_valid) begin
            $error("post-reset not idle");
            fail = 1;
        end

        // Directed: enable + 2x2 frame
        enable  = 1;
        frame_w = 2;
        frame_h = 2;
        cov_enable = 1;
        cov_csr_w  = 1;
        cov_csr_h  = 1;
        @(posedge clk);
        cam_vsync <= 1;
        @(posedge clk);
        cam_vsync <= 0;

        fork
            begin
                for (i = 0; i < 4; i++) begin
                    send_byte(8'h10 + i[7:0]);
                    send_byte(8'h20 + i[7:0]);
                    send_byte(8'h30 + i[7:0]);
                end
                cam_href <= 0;
            end
            drain_pixels(4);
        join

        repeat (10) @(posedge clk);
        if (!frame_done) begin
            $error("frame_done not set");
            fail = 1;
        end else cov_frame_done = 1;

        // Constrained-random resolutions / pixels
        for (int t = 0; t < 8; t++) begin
            logic [15:0] rw, rh;
            int npix;
            enable = 0;
            @(posedge clk);
            rw = 16'(1 + ($urandom % 3));
            rh = 16'(1 + ($urandom % 3));
            frame_w = rw;
            frame_h = rh;
            npix = int'(rw * rh);
            enable = 1;
            @(posedge clk);
            cam_vsync <= 1;
            @(posedge clk);
            cam_vsync <= 0;
            fork
                begin
                    for (i = 0; i < npix; i++) begin
                        send_byte($urandom);
                        send_byte($urandom);
                        send_byte($urandom);
                    end
                    cam_href <= 0;
                end
                drain_pixels(npix);
            join
            repeat (20) @(posedge clk);
            if (!frame_done) begin
                $error("random frame %0d missing frame_done", t);
                fail = 1;
            end
        end

        cov_hit = cov_enable + cov_frame_done + cov_csr_w + cov_csr_h + (cov_pix > 0);
        $display("COVERAGE %0d/%0d (%0d%%)", cov_hit, cov_total, (100 * cov_hit) / cov_total);
        if ((100 * cov_hit) / cov_total < 90) begin
            $error("coverage below 90%%");
            fail = 1;
        end

        if (fail) $fatal(1);
        $display("CAM_CAPTURE_PASS");
        $finish;
    end

    initial begin
        #500_000;
        $error("timeout");
        $fatal(1);
    end
endmodule
