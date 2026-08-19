// Dashcam SoC top — interface-complete stub integration
// Wishbone B4; CSR @ 0x1000_0000; SRAM @ 0x2000_0000
// USE_CPU=0 (default): external Wishbone master
// USE_CPU=1: picoRV32 stub master
`timescale 1ns / 1ps

module dashcam_soc_top #(
    parameter bit USE_CPU = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n_async,

    // External Wishbone master (used when USE_CPU=0)
    input  logic        ext_cyc,
    input  logic        ext_stb,
    input  logic        ext_we,
    input  logic [3:0]  ext_sel,
    input  logic [31:0] ext_adr,
    input  logic [31:0] ext_dat_w,
    output logic [31:0] ext_dat_r,
    output logic        ext_ack,

    // Camera pads
    input  logic        cam_vsync,
    input  logic        cam_href,
    input  logic [7:0]  cam_data,
    input  logic        cam_pclk_valid,

    // SPI pads
    output logic        spi_sclk,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs_n,

    // GPIO / pads via IOMUX
    input  logic [7:0]  pad_in,
    output logic [7:0]  pad_out,
    output logic [7:0]  pad_oe,

    // IRQ out (to external host or CPU)
    output logic        irq_out
);
    logic rst_n;

    // Master mux
    logic        m_cyc, m_stb, m_we, m_ack;
    logic [3:0]  m_sel;
    logic [31:0] m_adr, m_dat_w, m_dat_r;

    // CPU stub master
    logic        cpu_cyc, cpu_stb, cpu_we, cpu_ack;
    logic [3:0]  cpu_sel;
    logic [31:0] cpu_adr, cpu_dat_w, cpu_dat_r;

    // DMA master
    logic        dma_cyc, dma_stb, dma_we, dma_ack;
    logic [3:0]  dma_sel;
    logic [31:0] dma_adr, dma_dat_w, dma_dat_r;

    // Interconnect slaves
    logic        s0_cyc, s0_stb, s0_we, s0_ack;
    logic [3:0]  s0_sel;
    logic [31:0] s0_adr, s0_dat_w, s0_dat_r;
    logic        s1_cyc, s1_stb, s1_we, s1_ack;
    logic [3:0]  s1_sel;
    logic [31:0] s1_adr, s1_dat_w, s1_dat_r;

    // CSR control wires
    logic        cam_enable, cam_busy, cam_frame_done;
    logic [15:0] cam_frame_w, cam_frame_h;
    logic        dma_enable, dma_busy, dma_done;
    logic [31:0] dma_dst_addr, dma_length;
    logic [31:0] irq_enable, irq_pending, irq_pending_clear;
    logic [3:0]  iomux_sel;
    logic        sdspi_enable, sdspi_cs_n, sdspi_idle, sdspi_done;
    logic [7:0]  sdspi_data_w, sdspi_data_r;

    // Pixel stream
    logic        pix_valid, pix_ready;
    logic [23:0] pix_rgb;

    // IOMUX function side
    logic [7:0]  func_in, func_out, func_oe;

    rst_sync u_rst (
        .clk         (clk),
        .rst_n_async (rst_n_async),
        .rst_n       (rst_n)
    );

    picorv32_wb u_cpu (
        .clk     (clk),
        .rst_n   (rst_n),
        .irq     (irq_out),
        .wb_cyc  (cpu_cyc),
        .wb_stb  (cpu_stb),
        .wb_we   (cpu_we),
        .wb_sel  (cpu_sel),
        .wb_adr  (cpu_adr),
        .wb_dat_w(cpu_dat_w),
        .wb_dat_r(cpu_dat_r),
        .wb_ack  (cpu_ack)
    );

    // Master select: external vs CPU; DMA shares bus via simple priority (DMA wins when active)
    logic use_dma;
    assign use_dma = dma_cyc;

    always_comb begin
        if (use_dma) begin
            m_cyc   = dma_cyc;
            m_stb   = dma_stb;
            m_we    = dma_we;
            m_sel   = dma_sel;
            m_adr   = dma_adr;
            m_dat_w = dma_dat_w;
        end else if (USE_CPU) begin
            m_cyc   = cpu_cyc;
            m_stb   = cpu_stb;
            m_we    = cpu_we;
            m_sel   = cpu_sel;
            m_adr   = cpu_adr;
            m_dat_w = cpu_dat_w;
        end else begin
            m_cyc   = ext_cyc;
            m_stb   = ext_stb;
            m_we    = ext_we;
            m_sel   = ext_sel;
            m_adr   = ext_adr;
            m_dat_w = ext_dat_w;
        end
    end

    assign dma_ack   = use_dma ? m_ack : 1'b0;
    assign dma_dat_r = m_dat_r;
    assign cpu_ack   = (USE_CPU && !use_dma) ? m_ack : 1'b0;
    assign cpu_dat_r = m_dat_r;
    assign ext_ack   = (!USE_CPU && !use_dma) ? m_ack : 1'b0;
    assign ext_dat_r = m_dat_r;

    wb_interconnect u_wb (
        .clk     (clk),
        .rst_n   (rst_n),
        .m_cyc   (m_cyc),
        .m_stb   (m_stb),
        .m_we    (m_we),
        .m_sel   (m_sel),
        .m_adr   (m_adr),
        .m_dat_w (m_dat_w),
        .m_dat_r (m_dat_r),
        .m_ack   (m_ack),
        .s0_cyc  (s0_cyc),
        .s0_stb  (s0_stb),
        .s0_we   (s0_we),
        .s0_sel  (s0_sel),
        .s0_adr  (s0_adr),
        .s0_dat_w(s0_dat_w),
        .s0_dat_r(s0_dat_r),
        .s0_ack  (s0_ack),
        .s1_cyc  (s1_cyc),
        .s1_stb  (s1_stb),
        .s1_we   (s1_we),
        .s1_sel  (s1_sel),
        .s1_adr  (s1_adr),
        .s1_dat_w(s1_dat_w),
        .s1_dat_r(s1_dat_r),
        .s1_ack  (s1_ack)
    );

    soc_csr u_csr (
        .clk              (clk),
        .rst_n            (rst_n),
        .wb_cyc           (s0_cyc),
        .wb_stb           (s0_stb),
        .wb_we            (s0_we),
        .wb_sel           (s0_sel),
        .wb_adr           (s0_adr),
        .wb_dat_w         (s0_dat_w),
        .wb_dat_r         (s0_dat_r),
        .wb_ack           (s0_ack),
        .cam_enable       (cam_enable),
        .cam_frame_w      (cam_frame_w),
        .cam_frame_h      (cam_frame_h),
        .cam_busy         (cam_busy),
        .cam_frame_done   (cam_frame_done),
        .dma_enable       (dma_enable),
        .dma_dst_addr     (dma_dst_addr),
        .dma_length       (dma_length),
        .dma_busy         (dma_busy),
        .dma_done         (dma_done),
        .irq_enable       (irq_enable),
        .irq_pending      (irq_pending),
        .irq_pending_clear(irq_pending_clear),
        .iomux_sel        (iomux_sel),
        .sdspi_enable     (sdspi_enable),
        .sdspi_cs_n       (sdspi_cs_n),
        .sdspi_data_w     (sdspi_data_w),
        .sdspi_data_r     (sdspi_data_r),
        .sdspi_idle       (sdspi_idle),
        .sdspi_done       (sdspi_done)
    );

    cam_capture u_cam (
        .clk           (clk),
        .rst_n         (rst_n),
        .enable        (cam_enable),
        .frame_w       (cam_frame_w),
        .frame_h       (cam_frame_h),
        .busy          (cam_busy),
        .frame_done    (cam_frame_done),
        .cam_vsync     (cam_vsync),
        .cam_href      (cam_href),
        .cam_data      (cam_data),
        .cam_pclk_valid(cam_pclk_valid),
        .pix_valid     (pix_valid),
        .pix_rgb       (pix_rgb),
        .pix_ready     (pix_ready)
    );

    dma_engine u_dma (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (dma_enable),
        .dst_addr (dma_dst_addr),
        .length   (dma_length),
        .busy     (dma_busy),
        .done     (dma_done),
        .pix_valid(pix_valid),
        .pix_rgb  (pix_rgb),
        .pix_ready(pix_ready),
        .wb_cyc   (dma_cyc),
        .wb_stb   (dma_stb),
        .wb_we    (dma_we),
        .wb_sel   (dma_sel),
        .wb_adr   (dma_adr),
        .wb_dat_w (dma_dat_w),
        .wb_dat_r (dma_dat_r),
        .wb_ack   (dma_ack)
    );

    sram_ctrl u_sram (
        .clk     (clk),
        .rst_n   (rst_n),
        .wb_cyc  (s1_cyc),
        .wb_stb  (s1_stb),
        .wb_we   (s1_we),
        .wb_sel  (s1_sel),
        .wb_adr  (s1_adr),
        .wb_dat_w(s1_dat_w),
        .wb_dat_r(s1_dat_r),
        .wb_ack  (s1_ack)
    );

    irq_ctrl u_irq (
        .clk           (clk),
        .rst_n         (rst_n),
        .cam_irq       (cam_frame_done),
        .dma_irq       (dma_done),
        .irq_enable    (irq_enable),
        .pending_clear (irq_pending_clear),
        .irq_pending   (irq_pending),
        .irq_out       (irq_out)
    );

    // SDSPI / IOMUX
    assign func_out = 8'h00;
    assign func_oe  = 8'h00;

    iomux u_iomux (
        .clk     (clk),
        .rst_n   (rst_n),
        .sel     (iomux_sel),
        .pad_in  (pad_in),
        .pad_out (pad_out),
        .pad_oe  (pad_oe),
        .func_in (func_in),
        .func_out(func_out),
        .func_oe (func_oe)
    );

    sd_spi u_sdspi (
        .clk     (clk),
        .rst_n   (rst_n),
        .enable  (sdspi_enable),
        .cs_n    (sdspi_cs_n),
        .data_w  (sdspi_data_w),
        .data_r  (sdspi_data_r),
        .idle    (sdspi_idle),
        .done    (sdspi_done),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    // Keep func_in referenced
    wire unused_func = |func_in;
endmodule
