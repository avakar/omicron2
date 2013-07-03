module main(
    input rst_n,
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

wire clk_48, clk_sampler, clk_dram, clk_dram_n;
wire clk_locked;
clock_controller clkctrl(
    .rst(!rst_n),
    .clk_33(clk_33),
    .clk_48(clk_48),
    .clk_sampler(clk_sampler),
    .clk_dram(clk_dram),
    .clk_dram_n(clk_dram_n),
    .locked(clk_locked)
    );

wire irst = !rst_n || !clk_locked;

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
wire[3:0] io_byte_enable;

reg[23:0] sdram0_addr_latch;
reg[15:0] sdram0_wdata_latch;
reg sdram0_wvalid, sdram0_arvalid;
wire sdram0_wready, sdram0_arready;
wire[15:0] sdram0_rdata;
wire sdram0_rvalid;

cpu cpu0(
  .Clk(clk_48),
  .Reset(irst),

  .IO_Addr_Strobe(io_addr_strobe),
  .IO_Read_Strobe(io_read_strobe),
  .IO_Write_Strobe(io_write_strobe),
  .IO_Address(io_addr),
  .IO_Byte_Enable(io_byte_enable),
  .IO_Write_Data(io_write_data),
  .IO_Read_Data(io_read_data),
  .IO_Ready(io_ready || sdram0_rvalid || (sdram0_wvalid && sdram0_wready))
);

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;

wire usb_dp_out, usb_dn_out, usb_dir_out;
reg[6:0] usb_address;
wire usb_reset;

wire usb_transaction_active;
wire[3:0] usb_endpoint;
wire usb_direction_in;
wire usb_setup;
reg[1:0] usb_handshake;
wire[7:0] usb_data_out;
wire[7:0] usb_data_in;
wire usb_data_strobe;
wire usb_success;
reg usb_data_toggle;
reg usb_in_data_valid;
usb usb0(
    .rst_n(!irst),
    .clk_48(clk_48),

    .dp_in(usb_sp),
    .dn_in(usb_sn),
    .d0p_in(usb_dp),
    .d0n_in(usb_dn),

    .dp_out(usb_dp_out),
    .dn_out(usb_dn_out),
    .d_dir_out(usb_dir_out),

    .usb_address(usb_address),

    .usb_rst(usb_reset),

    .transaction_active(usb_transaction_active),
    .endpoint(usb_endpoint),
    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .data_toggle(usb_data_toggle),

    .handshake(usb_handshake),

    .data_out(usb_data_out),
    .data_in(usb_data_in),
    .data_in_valid(usb_in_data_valid),
    .data_strobe(usb_data_strobe),
    .success(usb_success)
    );

wire[31:0] usb_read_data_b;

reg usb_bank;
reg[6:0] usb_addr_ptr;
usb_ram usb_ram0(
    .clka(clk_48),
    .wea(usb_data_strobe && !usb_addr_ptr[6] && !usb_direction_in),
    .addra({usb_endpoint[1:0], usb_direction_in, usb_bank, usb_addr_ptr[5:0]}),
    .dina(usb_data_out),
    .douta(usb_data_in),

    .clkb(clk_48),
    .web((io_addr_strobe && io_write_strobe && io_addr[31:16] == 16'hC100)? io_byte_enable: 1'b0),
    .addrb(io_addr[9:2]),
    .dinb(io_write_data),
    .doutb(usb_read_data_b)
    );

assign usb_dp = usb_dir_out? usb_dp_out: 1'bz;
assign usb_dn = usb_dir_out? usb_dn_out: 1'bz;

reg usb_reset_prev, usb_reset_flag;
reg usb_attach;
assign usb_pup = usb_attach? 1'b1: 1'bz;

wire usb_ep0_toggle;
wire[1:0] usb_ep0_handshake;
wire usb_ep0_bank;
wire usb_ep0_in_data_valid;
wire[15:0] usb_ep0_ctrl_rd_data;
usb_ep usb_ep0(
    .clk(clk_48),

    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .success(usb_endpoint == 4'b0 && usb_success),
    .cnt(usb_addr_ptr),

    .toggle(usb_ep0_toggle),
    .handshake(usb_ep0_handshake),
    .bank(usb_ep0_bank),
    .in_data_valid(usb_ep0_in_data_valid),

    .ctrl_dir_in(io_addr[2]),
    .ctrl_rd_data(usb_ep0_ctrl_rd_data),
    .ctrl_wr_data(io_write_data[15:0]),
    .ctrl_wr_strobe(io_addr_strobe && io_write_strobe && {io_addr[31:4],4'b0} == 32'hC0000100)
    );

wire usb_ep1_toggle;
wire[1:0] usb_ep1_handshake;
wire usb_ep1_bank;
wire usb_ep1_in_data_valid;
wire[15:0] usb_ep1_ctrl_rd_data;
usb_ep usb_ep1(
    .clk(clk_48),

    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .success(usb_endpoint == 4'b1 && usb_success),
    .cnt(usb_addr_ptr),

    .toggle(usb_ep1_toggle),
    .handshake(usb_ep1_handshake),
    .bank(usb_ep1_bank),
    .in_data_valid(usb_ep1_in_data_valid),

    .ctrl_dir_in(io_addr[2]),
    .ctrl_rd_data(usb_ep1_ctrl_rd_data),
    .ctrl_wr_data(io_write_data[15:0]),
    .ctrl_wr_strobe(io_addr_strobe && io_write_strobe && {io_addr[31:4],4'b0} == 32'hC0000110)
    );

always @(*) begin
    case (usb_endpoint)
        4'd0: begin
            usb_data_toggle = usb_ep0_toggle;
            usb_in_data_valid = usb_ep0_in_data_valid;
            usb_bank = usb_ep0_bank;
            usb_handshake = usb_ep0_handshake;
        end
        4'd1: begin
            usb_data_toggle = usb_ep1_toggle;
            usb_in_data_valid = usb_ep1_in_data_valid;
            usb_bank = usb_ep1_bank;
            usb_handshake = usb_ep1_handshake;
        end
        default: begin
            usb_data_toggle = 1'bx;
            usb_in_data_valid = 1'bx;
            usb_bank = 1'bx;
            usb_handshake = hs_stall;
        end
    endcase
end

wire[56:0] dna;
wire dna_ready;
dnareader dna0(
    .rst(irst),
    .clk_48(clk_48),
    .dna(dna),
    .ready(dna_ready)
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

/*axi_async_w #(.aw(5)) axi_async_w_sampler(
    .rst_n(!irst),

    .clka(clk_48),
    .wvalida(axi_async_w_sampler_wvalid),
    .wreadya(axi_async_w_sampler_wready),
    .waddra(io_addr[4:0]),
    .wdataa(io_write_data),

    .clkb(clk_sampler),
    .wvalidb(s0_wvalid),
    .wreadyb(1'b1),
    .waddrb(s0_waddr),
    .wdatab(s0_wdata)
    );*/

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
        32'hC0000000:
            io_read_data = { usb_addr_ptr, 6'b0, usb_reset_flag, usb_attach };
        32'hC0000004:
            io_read_data = usb_address;
        32'hC0000008:
            io_read_data = sdram_enable;
        32'hC000010?:
            io_read_data = usb_ep0_ctrl_rd_data;
        32'hC000011?:
            io_read_data = usb_ep1_ctrl_rd_data;
        32'hC100????:
            io_read_data = usb_read_data_b;
        32'hC2000000:
            io_read_data = dna[31:0];
        32'hC2000004:
            io_read_data = { dna_ready, 6'b0, dna[56:32] };
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
        usb_attach <= 1'b0;
        usb_address <= 6'b0;
        usb_reset_flag <= 1'b0;
        usb_reset_prev <= 1'b0;
        usb_addr_ptr <= 1'b0;
        s0_fifo_rd <= 1'b0;
    end else begin
        s0_fifo_rd <= 1'b0;

        usb_reset_prev <= usb_reset;
        if (usb_reset && !usb_reset_prev)
            usb_reset_flag <= 1'b1;

        if (!usb_transaction_active) begin
            usb_addr_ptr <= 1'b0;
        end else if (usb_data_strobe) begin
            if (!usb_addr_ptr[6])
                usb_addr_ptr <= usb_addr_ptr + 1'b1;
        end

        io_ready <= io_addr_strobe && io_addr[31:28] != 4'hD && (io_write_strobe || io_read_strobe);
        if (io_addr_strobe && io_write_strobe) begin
            casez (io_addr)
                32'hC0000000: begin
                    usb_attach <= io_write_data[0];
                    if (io_write_data[2])
                        usb_reset_flag <= 1'b0;
                end
                32'hC0000004: begin
                    usb_address <= io_write_data[6:0];
                end
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
