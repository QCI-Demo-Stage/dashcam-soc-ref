// Smoke testbench for dashcam_soc_top (verilator_smoke flow)
// Drives a 4x4 RGB frame through the stub datapath, dumps PPM, prints SMOKE_PASS.
`timescale 1ns / 1ps

module tb_verilator_smoke;
    localparam int FRAME_W = 4;
    localparam int FRAME_H = 4;
    localparam int PIXELS  = FRAME_W * FRAME_H;
    localparam int LENGTH  = PIXELS * 4; // one word per pixel

    logic        clk;
    logic        rst_n_async;

    logic        ext_cyc, ext_stb, ext_we, ext_ack;
    logic [3:0]  ext_sel;
    logic [31:0] ext_adr, ext_dat_w, ext_dat_r;

    logic        cam_vsync, cam_href, cam_pclk_valid;
    logic [7:0]  cam_data;

    logic        spi_sclk, spi_mosi, spi_miso, spi_cs_n;
    logic [7:0]  pad_in, pad_out, pad_oe;
    logic        irq_out;

    // Expected pixel colors (deterministic pattern)
    logic [7:0] exp_r [0:PIXELS-1];
    logic [7:0] exp_g [0:PIXELS-1];
    logic [7:0] exp_b [0:PIXELS-1];

    integer i;
    integer fd;
    integer fail;
    logic [31:0] word;
    logic [7:0]  got_r, got_g, got_b;

    // Keep unused DUT outputs referenced for -Wall hygiene
    wire unused_pads = |{spi_sclk, spi_mosi, spi_cs_n, pad_out, pad_oe, irq_out, word[31:24]};

    dashcam_soc_top #(.USE_CPU(1'b0)) dut (
        .clk           (clk),
        .rst_n_async   (rst_n_async),
        .ext_cyc       (ext_cyc),
        .ext_stb       (ext_stb),
        .ext_we        (ext_we),
        .ext_sel       (ext_sel),
        .ext_adr       (ext_adr),
        .ext_dat_w     (ext_dat_w),
        .ext_dat_r     (ext_dat_r),
        .ext_ack       (ext_ack),
        .cam_vsync     (cam_vsync),
        .cam_href      (cam_href),
        .cam_data      (cam_data),
        .cam_pclk_valid(cam_pclk_valid),
        .spi_sclk      (spi_sclk),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso),
        .spi_cs_n      (spi_cs_n),
        .pad_in        (pad_in),
        .pad_out       (pad_out),
        .pad_oe        (pad_oe),
        .irq_out       (irq_out)
    );

    // 100 MHz clock (blocking toggle in always is intentional)
    // verilator lint_off BLKSEQ
    initial clk = 1'b0;
    always #5 clk = ~clk;
    // verilator lint_on BLKSEQ

    initial begin
        for (i = 0; i < PIXELS; i = i + 1) begin
            exp_r[i] = 8'(8'h10 + 8'(i));
            exp_g[i] = 8'(8'h40 + 8'(i));
            exp_b[i] = 8'(8'h80 + 8'(i));
        end
    end

    // Blocking assigns after @(posedge clk) — tasks are called from initial
    task automatic wb_write(input logic [31:0] adr, input logic [31:0] data);
        begin
            @(posedge clk);
            ext_cyc   = 1'b1;
            ext_stb   = 1'b1;
            ext_we    = 1'b1;
            ext_sel   = 4'hF;
            ext_adr   = adr;
            ext_dat_w = data;
            while (1) begin
                @(posedge clk);
                if (ext_ack) break;
            end
            ext_cyc = 1'b0;
            ext_stb = 1'b0;
            ext_we  = 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic wb_read(input logic [31:0] adr, output logic [31:0] data);
        begin
            @(posedge clk);
            ext_cyc   = 1'b1;
            ext_stb   = 1'b1;
            ext_we    = 1'b0;
            ext_sel   = 4'hF;
            ext_adr   = adr;
            ext_dat_w = 32'h0;
            while (1) begin
                @(posedge clk);
                if (ext_ack) begin
                    data = ext_dat_r;
                    break;
                end
            end
            ext_cyc = 1'b0;
            ext_stb = 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic cam_send_byte(input logic [7:0] b);
        begin
            @(posedge clk);
            cam_href       = 1'b1;
            cam_pclk_valid = 1'b1;
            cam_data       = b;
            @(posedge clk);
            cam_pclk_valid = 1'b0;
            // Allow DMA backpressure cycles
            repeat (8) @(posedge clk);
        end
    endtask

    initial begin
        fail           = 0;
        rst_n_async    = 1'b0;
        ext_cyc        = 1'b0;
        ext_stb        = 1'b0;
        ext_we         = 1'b0;
        ext_sel        = 4'h0;
        ext_adr        = 32'h0;
        ext_dat_w      = 32'h0;
        cam_vsync      = 1'b0;
        cam_href       = 1'b0;
        cam_data       = 8'h0;
        cam_pclk_valid = 1'b0;
        spi_miso       = 1'b0;
        pad_in         = 8'h0;

        repeat (5) @(posedge clk);
        rst_n_async = 1'b1;
        repeat (5) @(posedge clk);

        // Program CSR: frame 4x4, DMA dst/len, enable DMA then CAM
        wb_write(32'h1000_0008, FRAME_W);          // CAM_FRAME_W
        wb_write(32'h1000_000C, FRAME_H);          // CAM_FRAME_H
        wb_write(32'h1000_0108, 32'h2000_0000);    // DMA_DST_ADDR
        wb_write(32'h1000_010C, LENGTH);           // DMA_LENGTH
        wb_write(32'h1000_0100, 32'h1);            // DMA_CTRL.ENABLE
        wb_write(32'h1000_0000, 32'h1);            // CAM_CTRL.ENABLE

        // Start frame
        @(posedge clk);
        cam_vsync = 1'b1;
        @(posedge clk);
        cam_vsync = 1'b0;

        // Drive RGB bytes
        for (i = 0; i < PIXELS; i = i + 1) begin
            cam_send_byte(exp_r[i]);
            cam_send_byte(exp_g[i]);
            cam_send_byte(exp_b[i]);
            @(posedge clk);
            cam_href = 1'b0;
            @(posedge clk);
        end

        // Wait for DMA done
        begin
            logic [31:0] st;
            integer guard;
            guard = 0;
            st = 0;
            while (guard < 10000) begin
                wb_read(32'h1000_0104, st); // DMA_STATUS
                if (st[1]) break;           // DONE
                guard = guard + 1;
            end
            if (!st[1]) begin
                $error("timeout waiting for DMA done");
                fail = 1;
            end
            // Reference remaining status bits for lint
            if (|{st[0], st[31:2]} && 1'b0) fail = fail;
        end

        // Read back pixels from SRAM and write PPM
        fd = $fopen("out/frame_0000.ppm", "w");
        if (fd == 0) begin
            $error("cannot open out/frame_0000.ppm");
            $fatal(1);
        end
        $fwrite(fd, "P3\n%d %d\n255\n", FRAME_W, FRAME_H);

        for (i = 0; i < PIXELS; i = i + 1) begin
            wb_read(32'h2000_0000 + (i * 4), word);
            got_r = word[23:16];
            got_g = word[15:8];
            got_b = word[7:0];
            $fwrite(fd, "%0d %0d %0d\n", got_r, got_g, got_b);
            if (got_r !== exp_r[i] || got_g !== exp_g[i] || got_b !== exp_b[i]) begin
                $error("pixel %0d mismatch got %02x%02x%02x exp %02x%02x%02x",
                       i, got_r, got_g, got_b, exp_r[i], exp_g[i], exp_b[i]);
                fail = 1;
            end
        end
        $fclose(fd);

        if (fail != 0) begin
            $error("SMOKE_FAIL");
            $fatal(1);
        end

        // Touch unused_pads so the sink is not itself unused
        if (unused_pads && 1'b0) $display("unreachable");

        $display("SMOKE_PASS");
        $finish;
    end

    // Absolute timeout
    initial begin
        #2_000_000;
        $error("global timeout");
        $fatal(1);
    end
endmodule
