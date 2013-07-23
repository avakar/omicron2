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

wire clk_48, clk_dram, clk_sampler, clk_dram_out, clk_dram_out_n;
wire clk_locked;
clock_controller clkctrl(
    .rst(!extrst_n),
    .clk_33(clk_33),
    .clk_48(clk_48),
    .clk_sampler(clk_sampler),
    .clk_dram(clk_dram),
    .clk_dram_out(clk_dram_out),
    .clk_dram_out_n(clk_dram_out_n),
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
wire s0_fifo_rd;
wire s0_empty_enough;
sample_fifo s0_fifo(
  .rst(irst),
  .wr_clk(clk_sampler),
  .din(s0_data),
  .wr_en(s0_strobe),
  .full(),
  .overflow(),

  .rd_clk(clk_dram),
  .rd_en(s0_fifo_rd),
  .dout(s0_fifo_rd_data),
  .empty(s0_fifo_empty),
  .prog_empty(s0_empty_enough)
);

wire[31:0] io_addr;
reg[31:0] io_read_data;
wire[31:0] io_write_data;
reg io_ready;
wire io_write_strobe, io_read_strobe, io_addr_strobe;
wire[3:0] io_byte_enable;

reg io_awe_latch;
reg[31:0] io_addr_latch;

wire s0_bvalid;
wire sh0_bvalid;
wire[31:0] sh0_bdata;

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
  .IO_Ready(io_ready || s0_bvalid || sh0_bvalid)
);

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;

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

    .rx_j(usb_rx_j),
    .rx_se0(usb_rx_se0),

    .tx_en(usb_tx_en),
    .tx_j(usb_tx_j),
    .tx_se0(usb_tx_se0),

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
reg m_clk_oe_sync;
ODDR2 m_clk_buf(
    .D0(1'b1),
    .D1(1'b0),
    .C0(clk_dram_out),
    .C1(clk_dram_out_n),
    .CE(1'b1),
    .R(!m_clk_oe_sync),
    .S(1'b0),
    .Q(m_clk)
    );

always @(posedge clk_dram_out) begin
    m_clk_oe_sync <= m_clk_oe;
end

wire compressor_overflow_error;

wire br0_avalid;
wire br0_awe;
wire[31:2] br0_aaddr;
wire[31:0] br0_adata;
wire br0_bvalid;

wire[63:0] s0_index_data;
wire s0_index_valid;

sampler s0(
    .clk(clk_sampler),
    .rst_n(!irst),

    .s(ss),

    .out_data(s0_data),
    .out_valid(s0_strobe),

    .index_data(s0_index_data),
    .index_valid(s0_index_valid),

    .compressor_overflow_error(compressor_overflow_error),

    .avalid(br0_avalid),
    .awe(br0_awe),
    .aaddr({br0_aaddr[4:2], 2'b0}),
    .adata(br0_adata),
    .bvalid(br0_bvalid),
    .bdata()
    );

reg[8:0] s0_index_addr;
wire[31:0] s0_index_rd_data;
sampler_index_ram s0_index_ram(
    .clka(clk_sampler),
    .wea(s0_index_valid),
    .addra(s0_index_addr),
    .dina(s0_index_data),

    .clkb(clk_48),
    .addrb(io_addr[11:2]),
    .doutb(s0_index_rd_data)
    );

always @(posedge clk_sampler or posedge irst) begin
    if (irst) begin
        s0_index_addr <= 1'b0;
    end else begin
        if (s0_index_valid)
            s0_index_addr <= s0_index_addr + 1'b1;
    end
end

aaxi_async_bridge br0(
    .rst_n(!irst),

    .s_clk(clk_48),
    .s_avalid(io_addr_strobe && (io_write_strobe || io_read_strobe) && (io_addr[31:8] == 24'hC20001)),
    .s_awe(io_write_strobe),
    .s_aaddr(io_addr[31:2]),
    .s_adata(io_write_data),
    .s_astrb(io_byte_enable),
    .s_bvalid(s0_bvalid),
    .s_bdata(),

    .m_clk(clk_sampler),
    .m_avalid(br0_avalid),
    .m_aready(1'b1),
    .m_awe(br0_awe),
    .m_aaddr(br0_aaddr),
    .m_adata(br0_adata),
    .m_astrb(),
    .m_bvalid(br0_bvalid),
    .m_bdata(32'b0)
    );

wire br1_avalid;
wire br1_awe;
wire[31:2] br1_aaddr;
wire[31:0] br1_adata;
wire br1_bvalid;
wire[31:0] br1_bdata;
aaxi_async_bridge br1(
    .rst_n(!irst),

    .s_clk(clk_48),
    .s_avalid(io_addr_strobe && (io_write_strobe || io_read_strobe) && (io_addr[31:8] == 24'hC20002)),
    .s_awe(io_write_strobe),
    .s_aaddr(io_addr[31:2]),
    .s_adata(io_write_data),
    .s_astrb(io_byte_enable),
    .s_bvalid(sh0_bvalid),
    .s_bdata(sh0_bdata),

    .m_clk(clk_dram),
    .m_avalid(br1_avalid),
    .m_aready(1'b1),
    .m_awe(br1_awe),
    .m_aaddr(br1_aaddr),
    .m_adata(br1_adata),
    .m_astrb(),
    .m_bvalid(br1_bvalid),
    .m_bdata(br1_bdata)
    );

wire sh0_fifo_wr_en;
wire[15:0] sh0_wr_data;
wire sh0_wr_almost_full;

reg sh0_fifo_rd;
wire[15:0] sh0_fifo_rd_data;
wire sh0_fifo_empty;
sdram_rd_fifo sh0_fifo(
  .rst(irst),

  .wr_clk(clk_dram),
  .din(sh0_wr_data),
  .wr_en(sh0_fifo_wr_en),
  .full(),
  .prog_full(sh0_wr_almost_full),

  .rd_clk(clk_48),
  .rd_en(sh0_fifo_rd),
  .dout(sh0_fifo_rd_data),
  .empty(sh0_fifo_empty)
);

sdram_handler sh0(
    .rst_n(!irst && sdram_enable),
    .clk(clk_dram),

    .w_en(s0_fifo_rd),
    .w_data(s0_fifo_rd_data),
    .w_empty(s0_fifo_empty),

    .r_en(sh0_fifo_wr_en),
    .r_data(sh0_wr_data),
    .r_almost_full(sh0_wr_almost_full),

    .rprio(s0_empty_enough),

    .m_clk_oe(m_clk_oe),
    .m_cs_n(m_cs_n),
    .m_cke(m_cke),
    .m_a(m_a),
    .m_ba(m_ba),
    .m_ras_n(m_ras_n),
    .m_cas_n(m_cas_n),
    .m_we_n(m_we_n),
    .m_ldqm(m_ldqm),
    .m_udqm(m_udqm),
    .m_dq(m_dq),

    .avalid(br1_avalid),
    .aaddr(br1_aaddr[2:2]),
    .adata(br1_adata),
    .awe(br1_awe),
    .bvalid(br1_bvalid),
    .bdata(br1_bdata)
    );

always @(posedge clk_48) begin
    if (io_addr_strobe && (io_write_strobe || io_read_strobe)) begin
        io_addr_latch <= io_addr;
    end
end

always @(*) begin
    casez (io_addr_latch)
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
            io_read_data = { !sh0_fifo_empty };
        32'hC2000014:
            io_read_data = sh0_fifo_rd_data;
        32'hC20002??:
            io_read_data = sh0_bdata;
        32'hC2001???:
            io_read_data = s0_index_rd_data;
        /*32'hC20001??:
            io_read_data = s0_bdata;*/
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
        sh0_fifo_rd <= 1'b0;
    end else begin
        sh0_fifo_rd <= 1'b0;

        usb_reset_prev <= usb_reset;
        if (usb_reset && !usb_reset_prev)
            usb_reset_flag <= 1'b1;

        if (!usb_transaction_active) begin
            usb_addr_ptr <= 1'b0;
        end else if (usb_data_strobe) begin
            if (!usb_addr_ptr[6])
                usb_addr_ptr <= usb_addr_ptr + 1'b1;
        end

        io_ready <= io_addr_strobe && (io_addr[31:28] != 4'hD && io_addr[31:8] != 24'hC20001) && (io_write_strobe || io_read_strobe);
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
                        sh0_fifo_rd <= 1'b1;
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
