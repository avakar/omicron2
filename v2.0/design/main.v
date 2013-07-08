module main(
    input extrst_n,
    input clk_33,
    output[2:0] led,
    input[15:0] s,
    output[15:0] sd,

    output vio_33,
    output vio_50,

    output flash_cs,
    output flash_si,
    output flash_clk,
    input flash_so,

    inout usb_pup,
    input usb_sp,
    input usb_sn,
    inout usb_dp,
    inout usb_dn,

    output m_pwren,
    output m_clk,
    output m_cs_n,
    (* IOB = "FORCE" *) output m_cke,
    (* IOB = "FORCE" *) output[12:0] m_a,
    (* IOB = "FORCE" *) output[1:0] m_ba,
    (* IOB = "FORCE" *) output m_ras_n,
    (* IOB = "FORCE" *) output m_cas_n,
    (* IOB = "FORCE" *) output m_we_n,
    output m_ldqm,
    output m_udqm,
    inout[15:0] m_dq
    );

//---------------------------------------------------------------------
// Clocks and reset

wire clk_48, clk_sampler, clk_dram, clk_dram_n;
wire clk_locked;
clock_controller clkctrl(
    .rst(!extrst_n),
    .clk_33(clk_33),
    .clk_48(clk_48),
    .clk_sampler(clk_sampler),
    .clk_dram(clk_dram),
    .clk_dram_n(clk_dram_n),
    .locked(clk_locked)
    );

wire irst = !extrst_n || !clk_locked;

//---------------------------------------------------------------------
// Input/output conditioning

wire usb_rx_j_presync, usb_rx_j, usb_rx_se0;
IBUFDS usb_j_buf(.I(usb_sp), .IB(usb_sn), .O(usb_rx_j_presync));
synch usb_j_synch(clk_48, usb_rx_j_presync, usb_rx_j);
synch usb_se0_synch(clk_48, !usb_dp && !usb_dn, usb_rx_se0);

wire usb_tx_en, usb_tx_j, usb_tx_se0;
assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;

wire usb_pup_en;
assign usb_pup = usb_pup_en? 1'b1: 1'bz;

//---------------------------------------------------------------------
// Clocks and reset

spiviajtag spiviajtag0(
    .clk(flash_clk),
    .cs_n(flash_cs),
    .mosi(flash_si),
    .miso(flash_so)
);

wire[15:0] ss;
synch #(
    .w(16),
    .d(2)
    ) s_synch0(
    .clk(clk_sampler),
    .i(s),
    .o(ss)
    );

wire[15:0] s0_data;
wire s0_strobe;

wire[15:0] s0_fifo_rd_data;
wire s0_fifo_empty;
reg s0_fifo_rd;
sample_fifo s0_fifo(
  .rst(irst),
  .wr_clk(clk_sampler),
  .rd_clk(clk_48),
  .din(s0_data),
  .wr_en(s0_strobe),

  .rd_en(s0_fifo_rd),
  .dout(s0_fifo_rd_data),
  .full(),
  .overflow(),
  .empty(s0_fifo_empty)
);

wire[31:0] io_addr;
reg[31:0] io_read_data;
wire[31:0] io_write_data;
reg io_ready;
wire io_write_strobe, io_read_strobe, io_addr_strobe;
wire cpu_io_ready;

reg[23:0] sdram0_addr_latch;
reg[15:0] sdram0_wdata_latch;
reg sdram0_wvalid, sdram0_arvalid;
wire sdram0_wready, sdram0_arready;
wire[15:0] sdram0_rdata;
wire sdram0_rvalid;

assign cpu_io_ready = io_ready || sdram0_rvalid || (sdram0_wvalid && sdram0_wready);

system sys0(
    .rst_n(!irst),
    .clk_48(clk_48),

    .rx_j(usb_rx_j),
    .rx_se0(usb_rx_se0),
    .tx_en(usb_tx_en),
    .tx_j(usb_tx_j),
    .tx_se0(usb_tx_se0),
    .pup_en(usb_pup_en),

    .io_addr_strobe(io_addr_strobe),
    .io_read_strobe(io_read_strobe),
    .io_write_strobe(io_write_strobe),
    .io_addr(io_addr),
    .io_byte_enable(),
    .io_write_data(io_write_data),
    .io_read_data(io_read_data),
    .io_ready(cpu_io_ready)
    );

reg sdram_enable;
wire m_clk_oe;
ODDR2 m_clk_buf(
    .D0(1'b1),
    .D1(1'b0),
    .C0(clk_dram),
    .C1(clk_dram_n),
    .CE(m_clk_oe),
    .R(!sdram_enable),
    .S(1'b0),
    .Q(m_clk)
    );

assign m_cs_n = 1'b0;
reg[23:0] s0dma_waddr;
sdram sdram0(
    .rst(!sdram_enable),
    .clk(clk_48),

    .awaddr(sdram0_addr_latch),
    .wdata(sdram0_wdata_latch),
    .wvalid(sdram0_wvalid),
    .wready(sdram0_wready),

    .araddr(sdram0_addr_latch),
    .arready(sdram0_arready),
    .arvalid(sdram0_arvalid),
    .rdata(sdram0_rdata),
    .rvalid(sdram0_rvalid),

    .m_clk_oe(m_clk_oe),
    .m_cke(m_cke),
    .m_ras(m_ras_n),
    .m_cas(m_cas_n),
    .m_we(m_we_n),
    .m_ba(m_ba),
    .m_a(m_a),
    .m_dqm({m_udqm, m_ldqm}),
    .m_dq(m_dq)
    );

wire compressor_overflow_error;

wire s0_wvalid;
wire[4:0] s0_waddr;
wire[31:0] s0_wdata;
sampler s0(
    .clk(clk_sampler),
    .rst_n(!irst),

    .s(ss),

    .out_data(s0_data),
    .out_valid(s0_strobe),

    .compressor_overflow_error(compressor_overflow_error),

    .waddr(io_addr[4:0]),
    .wdata(io_write_data),
    .wvalid(io_addr_strobe && io_write_strobe && (io_addr[31:8] == 24'hC20001)),
    
    .araddr(5'b0),
    .arvalid(1'b0),
    .rdata(),
    .rvalid()
    );

always @(posedge clk_48) begin
    if (io_addr_strobe && (io_write_strobe || io_read_strobe))
        sdram0_addr_latch <= io_addr[25:2];

    if (sdram0_wvalid && sdram0_wready)
        sdram0_wvalid <= 1'b0;

    if (sdram0_arvalid && sdram0_arready)
        sdram0_arvalid <= 1'b0;

    if (io_addr_strobe && io_read_strobe && io_addr[31:28] == 4'hD)
        sdram0_arvalid <= 1'b1;

    if (io_addr_strobe && io_write_strobe && io_addr[31:28] == 4'hD) begin
        sdram0_wdata_latch <= io_write_data[15:0];
        sdram0_wvalid <= 1'b1;
    end
end

always @(*) begin
    casez (io_addr)
        32'hC0000008:
            io_read_data = sdram_enable;
        32'hC2000010:
            io_read_data = { !s0_fifo_empty };
        32'hC2000014:
            io_read_data = s0_fifo_rd_data;
        32'hD???????:
            io_read_data = sdram0_rdata;
        default:
            io_read_data = 32'sbx;
    endcase
end

always @(posedge clk_48 or posedge irst) begin
    if (irst) begin
        sdram_enable <= 1'b0;
        io_ready <= 1'b0;
        s0_fifo_rd <= 1'b0;
    end else begin
        s0_fifo_rd <= 1'b0;

        io_ready <= io_addr_strobe && io_addr[31:28] != 4'hD && (io_write_strobe || io_read_strobe);
        if (io_addr_strobe && io_write_strobe) begin
            casez (io_addr)
                32'hC0000008: begin
                    sdram_enable <= io_write_data[0];
                end
                32'hC2000010: begin
                    if (io_write_data[0])
                        s0_fifo_rd <= 1'b1;
                end
            endcase
        end
    end
end

assign sd = 16'b0000000010000000;

assign vio_33 = 1'b1;
assign vio_50 = 1'b0;
assign m_pwren = sdram_enable;

assign led = { compressor_overflow_error, 1'b0, 1'b1 };

endmodule
