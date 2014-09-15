module main(
    input clk_33,
    output[2:0] led,
    
    output vio33,
    output vio50,
    
    inout usb_dp,
    inout usb_dn,
    input usb_sp,
    input usb_sn,
    inout usb_pullup,
    
    output reg spi_cs,
    output reg spi_clk,
    output reg spi_mosi,
    input spi_miso,
    
    output reg m_pwren,
    output m_clk,
    output m_cs_n,
    output m_cke,
    output[12:0] m_a,
    output[1:0] m_ba,
    output m_ras_n,
    output m_cas_n,
    output m_we_n,
    output m_ldqm,
    output m_udqm,
    inout[15:0] m_dq,

    input[15:0] s,
    output[15:0] sd
    );

wire rst_n;
wire clk_48;
wire clk_sampler;
wire clk_dram;
wire clk_dram_out;
wire clk_dram_out_n;

wire strobe_1hz;
wire strobe_4mhz;

assign vio33 = 1'b0;
assign vio50 = 1'b0;

assign sd = 16'b0;

//---------------------------------------------------------------------
// I/O space

/* 32'hC0000000 */ reg[2:0] io_ledbits;
/* 32'hC0000004 */ reg[31:0] io_tmr;

/* 32'hC0000008:0 */ reg io_usb_attach;
/* 32'hC0000008:1 */ reg io_usb_reset_flag;
/* 32'hC0000008:2 */ //wire io_usb_reset_flag_clr;
/* 32'hC0000009 */ reg[6:0] io_usb_addr_ptr;
/* 32'hC000000C */ reg[6:0] io_usb_address;

/* 32'hC0000010 */ wire[15:0] io_usb_ep0_ctrl;
/* 32'hC0000014 */ //wire[15:0] io_usb_ep0_ctrl;
/* 32'hC0000018 */ wire[15:0] io_usb_ep1_ctrl;
/* 32'hC000001C */ //wire[15:0] io_usb_ep1_ctrl;

/* 32'hC0000020 */ wire[7:0] io_spi_ctrl;
/* 32'hC0000024 */ wire[7:0] io_spi_data;
/* 32'hC0000028 */ wire[7:0] io_icap_ctrl;
/* 32'hC000002C */ //wire[15:0] io_icap_data;

/* 32'hC0000030 */ wire[63:0] io_dna;

/* 32'hC0000040 */ wire[15:0] io_usb_ep2_ctrl;
/* 32'hC0000044 */ //wire[15:0] io_usb_ep2_ctrl;

/* 32'hC0001000 */ wire[31:0] io_usb_mem;

/* 32'hD0000000 */ wire[31:0] io_br100;
wire io_br100_ready;

/* 32'hE0000000 */ wire[31:0] io_br200;
wire io_br200_ready;

wire cpu0_io_addr_strobe;
wire cpu0_io_read_strobe;
wire cpu0_io_write_strobe;
wire[31:0] cpu0_io_address;
wire[3:0] cpu0_io_byte_enable;
reg cpu0_io_ready;
wire[31:0] cpu0_io_write_data;
reg[31:0] cpu0_io_read_data;

reg cpu0_io_read_latency_cnt;

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        cpu0_io_ready <= 1'b0;
        cpu0_io_read_latency_cnt <= 1'b0;
    end else begin
        cpu0_io_ready <= cpu0_io_read_latency_cnt || io_br100_ready || io_br200_ready;
        cpu0_io_read_latency_cnt <= cpu0_io_addr_strobe && (cpu0_io_read_strobe || cpu0_io_write_strobe) && cpu0_io_address[31:28] == 4'hC;
    end
end

always @(*) begin
    casez ({ cpu0_io_address[31:2], 2'b00 })
        32'hC0000000: cpu0_io_read_data <= io_ledbits;
        32'hC0000004: cpu0_io_read_data <= io_tmr;
        32'hC0000008: cpu0_io_read_data <= { io_usb_addr_ptr, 6'b0, io_usb_reset_flag, io_usb_attach };
        32'hC000000C: cpu0_io_read_data <= io_usb_address;
        32'hC0000010: cpu0_io_read_data <= io_usb_ep0_ctrl;
        32'hC0000014: cpu0_io_read_data <= io_usb_ep0_ctrl;
        32'hC0000018: cpu0_io_read_data <= io_usb_ep1_ctrl;
        32'hC000001C: cpu0_io_read_data <= io_usb_ep1_ctrl;
        32'hC0000020: cpu0_io_read_data <= io_spi_ctrl;
        32'hC0000024: cpu0_io_read_data <= io_spi_data;
        32'hC0000028: cpu0_io_read_data <= io_icap_ctrl;
        32'hC0000030: cpu0_io_read_data <= io_dna[31:0];
        32'hC0000034: cpu0_io_read_data <= io_dna[63:32];
        32'hC0000040: cpu0_io_read_data <= io_usb_ep2_ctrl;
        32'hC0000044: cpu0_io_read_data <= io_usb_ep2_ctrl;
        32'hC0001???: cpu0_io_read_data <= io_usb_mem;
        32'hD???????: cpu0_io_read_data <= io_br100;
        32'hE???????: cpu0_io_read_data <= io_br200;
        default: cpu0_io_read_data <= 32'hxxxxxxxx;
    endcase
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        io_ledbits <= 3'b100;
    end else begin
        if (cpu0_io_addr_strobe && cpu0_io_write_strobe) begin
            case ({cpu0_io_address[31:2], 2'b00})
                32'hC0000000: io_ledbits <= cpu0_io_write_data[2:0];
            endcase
        end
    end
end

//---------------------------------------------------------------------
// CPU

cpu cpu0(
    .Clk(clk_48),
    .Reset(!rst_n),

    .IO_Addr_Strobe(cpu0_io_addr_strobe),
    .IO_Read_Strobe(cpu0_io_read_strobe),
    .IO_Write_Strobe(cpu0_io_write_strobe),
    .IO_Address(cpu0_io_address),
    .IO_Byte_Enable(cpu0_io_byte_enable),
    .IO_Write_Data(cpu0_io_write_data),
    .IO_Read_Data(cpu0_io_read_data),
    .IO_Ready(cpu0_io_ready)
);

//---------------------------------------------------------------------
// I/O space @ clk_dram

reg io100_awe;
wire[31:0] io100_address;
wire[31:0] io100_adata;
reg[31:0] io100_bdata;
wire io100_avalid;

/* 32'hD0000000 */ wire[31:0] io100_test_bdata;
/* 32'hD0000010 */ wire[31:0] io100_sdram_ctrl_bdata;
/* 32'hD0000020 */ reg[23:0] io100_sdram_dma_rdaddr;
/* 32'hD0000024 */ wire[31:0] io100_sdram_dma_rdstatus;
/* 32'hD0000028 */ reg[23:0] io100_sdram_dma_wraddr;
/* 32'hD000002C */ wire[31:0] io100_sdram_dma_wrstatus;
/* 32'hD0000030 */ wire[31:0] io100_sdram_dma_sfaddr;
reg[4:0] usb_ep2_wr_addr;

reg io100_ctrl_bvalid;
always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        io100_ctrl_bvalid <= 1'b0;
    end else begin
        io100_ctrl_bvalid <= io100_avalid && io100_address[31:24] == 8'hD0;
    end
end

wire io100_aready = io100_address[31:24] == 8'hD0;
wire io100_bvalid = io100_ctrl_bvalid;

always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        io100_bdata <= 32'hxxxxxxxx;
    end else if (io100_bvalid) begin
        io100_bdata <= 32'hxxxxxxxx;
        casez ({ io100_address[31:2], 2'b00 })
            32'hD0000000: io100_bdata <= io100_test_bdata;
            32'hD0000010: io100_bdata <= io100_sdram_ctrl_bdata;
            32'hD0000020: io100_bdata <= { usb_ep2_wr_addr, io100_sdram_dma_rdaddr };
            32'hD0000024: io100_bdata <= io100_sdram_dma_rdstatus;
            32'hD0000028: io100_bdata <= io100_sdram_dma_wraddr;
            32'hD000002C: io100_bdata <= io100_sdram_dma_wrstatus;
            32'hD0000030: io100_bdata <= io100_sdram_dma_sfaddr;
        endcase
    end
end

//---------------------------------------------------------------------
// clk_dram I/O bridge

reg[3:0] br100_addr_strobe;
reg[3:0] br100_ready;

assign io_br100_ready = br100_ready[3] != br100_ready[2];

assign io100_address = cpu0_io_address;
assign io100_adata = cpu0_io_write_data;

assign io_br100 = io100_bdata;

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        br100_ready[3:1] <= 3'b0;
        br100_addr_strobe[0] <= 1'b0;
        io100_awe <= 1'b0;
    end else begin
        br100_ready[3:1] <= br100_ready[2:0];
        if (cpu0_io_addr_strobe && cpu0_io_address[31:28] == 4'hD) begin
            io100_awe <= cpu0_io_write_strobe;
            br100_addr_strobe[0] <= !br100_addr_strobe[0];
        end
    end
end

assign io100_avalid = br100_addr_strobe[3] != br100_addr_strobe[2];

always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        br100_addr_strobe[3:1] <= 3'b0;
        br100_ready[0] <= 1'b0;
    end else begin
        br100_addr_strobe[2:1] <= br100_addr_strobe[1:0];
        if (io100_aready)
            br100_addr_strobe[3] <= br100_addr_strobe[2];
        if (io100_bvalid)
            br100_ready[0] <= !br100_ready[0];
    end
end

//---------------------------------------------------------------------
// clk_sampler I/O bridge

wire io200_avalid;
wire io200_aready = 1'b1;
reg io200_awe;
reg[4:0] io200_aaddr;
reg[31:0] io200_adata;
wire io200_bvalid;
wire[31:0] io200_bdata;

reg[3:0] br200_avalid;
reg[3:0] br200_bvalid;
reg[31:0] br200_bdata;
assign io_br200_ready = br200_bvalid[3] != br200_bvalid[2];
assign io200_avalid = br200_avalid[3] != br200_avalid[2];
assign io_br200 = br200_bdata;

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        br200_avalid[0] <= 1'b0;
        br200_bvalid[3:1] <= 1'b0;
    end else begin
        br200_bvalid[3:1] <= br200_bvalid[2:0];
        if (cpu0_io_addr_strobe && (cpu0_io_read_strobe || cpu0_io_write_strobe) && cpu0_io_address[31:28] == 4'hE) begin
            io200_adata <= cpu0_io_write_data;
            io200_aaddr <= cpu0_io_address[4:0];
            io200_awe <= cpu0_io_write_strobe;
            br200_avalid[0] <= !br200_avalid[0];
        end
    end
end

always @(posedge clk_sampler or negedge rst_n) begin
    if (!rst_n) begin
        br200_bvalid[0] <= 1'b0;
        br200_avalid[3:1] <= 1'b0;
    end else begin
        br200_avalid[2:1] <= br200_avalid[1:0];
        if (io200_avalid && io200_aready)
            br200_avalid[3] <= br200_avalid[2];
        if (io200_bvalid) begin
            br200_bvalid[0] <= !br200_bvalid[0];
            br200_bdata <= io200_bdata;
        end
    end
end

//---------------------------------------------------------------------
// sampler

wire[15:0] sampler0_out_data;
wire sampler0_out_valid;

wire sdram_dma_prio_usb;
wire sf0_rd_en;
wire[15:0] sf0_dout;
wire sf0_empty;

sample_fifo sf0(
    .rst(!rst_n),

    .wr_clk(clk_sampler),
    .din(sampler0_out_data),
    .wr_en(sampler0_out_valid),
    .full(),

    .rd_clk(clk_dram),
    .rd_en(sf0_rd_en),
    .dout(sf0_dout),
    .empty(sf0_empty),
    .prog_empty(sdram_dma_prio_usb)
    );

sampler sampler0(
    .rst_n(rst_n),
    .clk(clk_sampler),

    .s(s),

    .out_data(sampler0_out_data),
    .out_valid(sampler0_out_valid),

    .avalid(io200_avalid),
    .awe(io200_awe),
    .aaddr(io200_aaddr),
    .adata(io200_adata),
    .bvalid(io200_bvalid),
    .bdata(io200_bdata)
    );

//---------------------------------------------------------------------
// TEST100

reg[31:0] test100;
assign io100_test_bdata = test100;
always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        test100 <= 1'b0;
    end else begin
        if (io100_avalid && io100_awe && { io100_address[31:2], 2'b00 } == 32'hD0000000)
            test100 <= io100_adata;
    end
end

//---------------------------------------------------------------------
// SDRAM

assign io100_sdram_ctrl_bdata = { 30'b0, m_pwren };
always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        m_pwren <= 1'b0;
    end else begin
        if (io100_avalid && io100_awe && { io100_address[31:2], 2'b00 } == 32'hD0000010)
            m_pwren <= io100_adata[0];
    end
end

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

always @(posedge clk_dram_out or negedge rst_n) begin
    if (!rst_n) begin
        m_clk_oe_sync <= 1'b0;
    end else begin
        m_clk_oe_sync <= m_clk_oe;
    end
end

assign m_cs_n = 1'b0;

wire[15:0] s0_bdata;
wire s0_bvalid;
wire s0_avalid;
wire s0_aready;
wire s0_bwe;

wire[15:0] usb_ep2_wr_data = s0_bdata;
wire usb_ep2_wr_en = s0_bvalid && !s0_bwe;
wire usb_ep2_wr_push = usb_ep2_wr_en && usb_ep2_wr_addr == 5'd31;
wire usb_ep2_wr_full;

wire[15:0] usb_ep2_rd_data;
wire usb_ep2_rd_pull;
wire usb_ep2_rd_empty;

reg sdram_dma_wrenable;
reg sdram_dma_rdenable;
assign io100_sdram_dma_rdstatus = { usb_ep2_wr_addr != io100_sdram_dma_rdaddr[4:0], 1'b0, sdram_dma_rdenable };
assign io100_sdram_dma_wrstatus = { usb_ep2_rd_empty, sdram_dma_wrenable };

wire s0_usbrd_avalid = sdram_dma_rdenable && (io100_sdram_dma_rdaddr[4:0] != 1'b0 || (usb_ep2_wr_addr == 1'b0 && !usb_ep2_wr_full));
wire s0_usbwr_avalid = !usb_ep2_rd_empty && sdram_dma_wrenable;
wire s0_sf_avalid = !sf0_empty;

wire s0_sf_selected = s0_sf_avalid && (!sdram_dma_prio_usb || (!s0_usbrd_avalid && !s0_usbwr_avalid));

wire s0_awe = s0_sf_selected || s0_usbwr_avalid;

assign sf0_rd_en = s0_sf_selected && s0_aready;

reg[23:0] sdram_dma_sf0_wraddr;
assign io100_sdram_dma_sfaddr = sdram_dma_sf0_wraddr;

reg sc0_avalid;
wire sc0_aready;
assign s0_aready = !sc0_avalid || sc0_aready;
reg sc0_awe;
reg[23:0] sc0_aaddr;
reg[15:0] sc0_adata;
always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        sc0_avalid <= 1'b0;
    end else begin
        if (s0_avalid && s0_aready) begin
            sc0_awe <= s0_awe;
            sc0_aaddr <= s0_sf_selected? sdram_dma_sf0_wraddr: (s0_usbwr_avalid? io100_sdram_dma_wraddr: io100_sdram_dma_rdaddr);
            sc0_adata <= s0_sf_selected? sf0_dout: usb_ep2_rd_data;
            sc0_avalid <= 1'b1;
        end

        if (!s0_avalid && sc0_aready)
            sc0_avalid <= 1'b0;
    end
end

sdram s0(
    .rst(!rst_n || !m_pwren),
    .clk(clk_dram),

    .avalid(sc0_avalid),
    .aready(sc0_aready),
    .awe(sc0_awe),
    .aaddr(sc0_aaddr),
    .adata(sc0_adata),
    .bvalid(s0_bvalid),
    .bwe(s0_bwe),
    .bdata(s0_bdata),

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

assign s0_avalid = s0_usbrd_avalid || s0_usbwr_avalid || s0_sf_avalid;
assign usb_ep2_rd_pull = !s0_sf_selected && s0_usbwr_avalid && s0_aready;

always @(posedge clk_dram or negedge rst_n) begin
    if (!rst_n) begin
        io100_sdram_dma_rdaddr <= 1'b0;
        usb_ep2_wr_addr <= 1'b0;
        sdram_dma_rdenable <= 1'b1;
        sdram_dma_wrenable <= 1'b1;
        sdram_dma_sf0_wraddr <= 1'b0;
    end else begin
        if (s0_avalid && s0_aready) begin
            if (s0_sf_selected)
                sdram_dma_sf0_wraddr <= sdram_dma_sf0_wraddr + 1'b1;
            else if (!s0_usbwr_avalid)
                io100_sdram_dma_rdaddr <= io100_sdram_dma_rdaddr + 1'b1;
            else
                io100_sdram_dma_wraddr <= io100_sdram_dma_wraddr + 1'b1;
        end

        if (usb_ep2_wr_en)
            usb_ep2_wr_addr <= usb_ep2_wr_addr + 1'b1;

        if (io100_avalid && io100_awe) begin
            casez ({ io100_address[31:2], 2'b00 })
                32'hD0000020: begin
                    io100_sdram_dma_rdaddr <= { io100_adata[23:5], 5'b0 };
                    usb_ep2_wr_addr <= 1'b0;
                end
                32'hD0000024: begin
                    sdram_dma_rdenable <= io100_adata[0];
                end
                32'hD0000028: begin
                    io100_sdram_dma_wraddr <= io100_adata[23:0];
                end
                32'hD000002C: begin
                    sdram_dma_wrenable <= io100_adata[0];
                end
            endcase
        end
    end
end

//---------------------------------------------------------------------
// ICAP

wire[15:0] io_icap0_ctrl;

reg icap0_ce_n;
reg icap0_clk;
reg[15:0] icap0_data;

ICAP_SPARTAN6 icap0(
    .CLK(icap0_clk),
    .CE(icap0_ce_n),
    .WRITE(1'b0),
    .I(icap0_data),
    .O(),
    .BUSY()
    );

reg icap0_run_clk;
reg icap0_next_clk;
assign io_icap_ctrl = { 13'b0, icap0_run_clk, icap0_clk || icap0_next_clk, !icap0_ce_n };

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        icap0_ce_n <= 1'b1;
        icap0_run_clk <= 1'b1;
        icap0_clk <= 1'b0;
        icap0_next_clk <= 1'b0;
        icap0_data <= 16'hxxxx;
    end else begin
        icap0_clk <= icap0_next_clk;
        icap0_next_clk <= icap0_run_clk? !icap0_next_clk: 1'b0;

        if (cpu0_io_addr_strobe && cpu0_io_write_strobe) begin
            case ({cpu0_io_address[31:2], 2'b00})
                32'hC0000028: begin
                    icap0_ce_n <= !cpu0_io_write_data[0];
                    icap0_run_clk <= cpu0_io_write_data[2];
                end
                32'hC000002C: begin
                    icap0_data <= {
                        cpu0_io_write_data[8],
                        cpu0_io_write_data[9],
                        cpu0_io_write_data[10],
                        cpu0_io_write_data[11],
                        cpu0_io_write_data[12],
                        cpu0_io_write_data[13],
                        cpu0_io_write_data[14],
                        cpu0_io_write_data[15],
                        cpu0_io_write_data[0],
                        cpu0_io_write_data[1],
                        cpu0_io_write_data[2],
                        cpu0_io_write_data[3],
                        cpu0_io_write_data[4],
                        cpu0_io_write_data[5],
                        cpu0_io_write_data[6],
                        cpu0_io_write_data[7]
                        };
                    icap0_next_clk <= 1'b1;
                end
            endcase
        end
    end
end

//---------------------------------------------------------------------
// SPI

reg[7:0] data_out;
reg[3:0] data_cnt;

assign io_spi_ctrl = { 6'b0, data_cnt || !spi_clk, spi_cs };
assign io_spi_data = data_out;

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        spi_cs <= 1'b1;
        spi_clk <= 1'b1;
        spi_mosi <= 1'b1;
    end else begin
        if (cpu0_io_addr_strobe && cpu0_io_write_strobe) begin
            case ({cpu0_io_address[31:2], 2'b00})
                32'hC0000020: begin
                    spi_cs <= cpu0_io_write_data[0];
                end
                32'hC0000024: begin
                    data_out <= cpu0_io_write_data[7:0];
                    data_cnt <= 4'd8;
                end
            endcase
        end

        if (spi_clk && data_cnt) begin
            spi_mosi <= data_out[7];
            data_out <= { data_out[6:0], 1'b0 };
            spi_clk <= 1'b0;
            data_cnt <= data_cnt - 1'b1;
        end

        if (!spi_clk) begin
            data_out[0] <= spi_miso;
            spi_clk <= 1'b1;
        end
    end
end

//---------------------------------------------------------------------
// TIMER

reg[5:0] tmr_prescale;
always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        io_tmr <= 1'b0;
        tmr_prescale <= 1'b0;
    end else begin
        tmr_prescale <= tmr_prescale + 1'b1;
        if (tmr_prescale == 6'd47) begin
            tmr_prescale <= 1'b0;
            io_tmr <= io_tmr + 1'b1;
        end
    end
end

//---------------------------------------------------------------------
// USB

wire usb_rx_j_presync, usb_rx_j, usb_rx_se0;
IBUFDS usb_j_buf(.I(usb_sp), .IB(usb_sn), .O(usb_rx_j_presync));
synch usb_j_synch(clk_48, usb_rx_j_presync, usb_rx_j);
synch usb_se0_synch(clk_48, !usb_dp && !usb_dn, usb_rx_se0);

wire usb_tx_en, usb_tx_j, usb_tx_se0;
assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;
assign usb_pullup = io_usb_attach? 1'b1: 1'bz;

wire usb_rst;
wire usb0_transaction_active;
wire usb0_direction_in;
wire usb0_data_strobe;
wire usb0_setup;
reg usb0_toggle;
reg[1:0] usb0_handshake;
reg usb0_in_data_valid;
wire usb0_success;
wire[3:0] usb0_endpoint;
wire[7:0] usb0_data_out;
reg[7:0] usb0_data_in;
usb usb0(
    .rst_n(rst_n),
    .clk_48(clk_48),

    .rx_j(usb_rx_j),
    .rx_se0(usb_rx_se0),

    .tx_en(usb_tx_en),
    .tx_j(usb_tx_j),
    .tx_se0(usb_tx_se0),

    .usb_address(io_usb_address),

    .usb_rst(usb_rst),

    .transaction_active(usb0_transaction_active),
    .endpoint(usb0_endpoint),
    .direction_in(usb0_direction_in),
    .setup(usb0_setup),
    .data_toggle(usb0_toggle),

    .handshake(usb0_handshake),
    
    .data_out(usb0_data_out),
    .data_in(usb0_data_in),
    .data_in_valid(usb0_in_data_valid),
    .data_strobe(usb0_data_strobe),
    .success(usb0_success)
    );

reg usb_mem0_bank_usb;
reg usb_mem0_bank_in;
reg usb_mem0_bank_out;
wire[7:0] usb_mem0_douta;
usb_mem usb_mem0(
    .clka(clk_48),
    .wea(usb0_transaction_active && usb0_endpoint < 2 && !usb0_direction_in && usb0_data_strobe && !io_usb_addr_ptr[6]),
    .addra({ usb_mem0_bank_usb, usb0_endpoint[0], usb0_direction_in, io_usb_addr_ptr[5:0] }),
    .dina(usb0_data_out),
    .douta(usb_mem0_douta),

    .clkb(clk_48),
    .web((cpu0_io_addr_strobe && cpu0_io_write_strobe && cpu0_io_address[31:12] == 20'hC0001)? cpu0_io_byte_enable: 4'b0000),
    .addrb({ cpu0_io_address[6]? usb_mem0_bank_in: usb_mem0_bank_out, cpu0_io_address[7:2] }),
    .dinb(cpu0_io_write_data),
    .doutb(io_usb_mem)
    );

wire usb_ep0_toggle;
wire usb_ep0_bank_usb;
wire usb_ep0_bank_in;
wire usb_ep0_bank_out;
wire usb_ep0_in_data_valid;
wire[1:0] usb_ep0_handshake;
usb_ep usb_ep0(
    .clk(clk_48),

    .direction_in(usb0_direction_in),
    .setup(usb0_setup),
    .success(usb0_endpoint == 4'd0 && usb0_success),
    .cnt(io_usb_addr_ptr),

    .toggle(usb_ep0_toggle),
    .handshake(usb_ep0_handshake),
    .bank_usb(usb_ep0_bank_usb),
    .bank_in(usb_ep0_bank_in),
    .bank_out(usb_ep0_bank_out),
    .in_data_valid(usb_ep0_in_data_valid),

    .ctrl_dir_in(cpu0_io_address[2]),
    .ctrl_rd_data(io_usb_ep0_ctrl),
    .ctrl_wr_data(cpu0_io_write_data[15:0]),
    .ctrl_wr_en((cpu0_io_addr_strobe && cpu0_io_write_strobe && {cpu0_io_address[31:3], 3'b000} == 32'hC0000010)? cpu0_io_byte_enable[1:0]: 2'b00)
    );

wire usb_ep1_toggle;
wire usb_ep1_bank_usb;
wire usb_ep1_bank_in;
wire usb_ep1_bank_out;
wire usb_ep1_in_data_valid;
wire[1:0] usb_ep1_handshake;
usb_ep_banked usb_ep1(
    .clk(clk_48),

    .direction_in(usb0_direction_in),
    .setup(usb0_setup),
    .success(usb0_endpoint == 4'd1 && usb0_success),
    .cnt(io_usb_addr_ptr),

    .toggle(usb_ep1_toggle),
    .handshake(usb_ep1_handshake),
    .bank_usb(usb_ep1_bank_usb),
    .bank_in(usb_ep1_bank_in),
    .bank_out(usb_ep1_bank_out),
    .in_data_valid(usb_ep1_in_data_valid),

    .ctrl_dir_in(cpu0_io_address[2]),
    .ctrl_rd_data(io_usb_ep1_ctrl),
    .ctrl_wr_data(cpu0_io_write_data[15:0]),
    .ctrl_wr_en((cpu0_io_addr_strobe && cpu0_io_write_strobe && {cpu0_io_address[31:3], 3'b000} == 32'hC0000018)? cpu0_io_byte_enable[1:0]: 2'b00)
    );

wire usb_ep2_toggle;
wire usb_ep2_in_data_valid;
wire[1:0] usb_ep2_handshake;
wire[7:0] usb_ep2_in_data;
sdram_usb_ep usb_ep2(
    .rst_n(rst_n),
    .clk(clk_48),

    .transaction_active(usb0_transaction_active && usb0_endpoint == 2),
    .direction_in(usb0_direction_in),
    .success(usb0_endpoint == 4'd2 && usb0_success),
    .cnt(io_usb_addr_ptr),

    .toggle(usb_ep2_toggle),
    .handshake(usb_ep2_handshake),
    .in_data_valid(usb_ep2_in_data_valid),
    .in_data(usb_ep2_in_data),
    .out_data(usb0_data_out),
    .data_strobe(usb0_transaction_active && usb0_endpoint == 2 && usb0_data_strobe && !io_usb_addr_ptr[6]),

    .ctrl_dir_in(cpu0_io_address[2]),
    .ctrl_rd_data(io_usb_ep2_ctrl),
    .ctrl_wr_data(cpu0_io_write_data[7:0]),
    .ctrl_wr_en((cpu0_io_addr_strobe && cpu0_io_write_strobe && {cpu0_io_address[31:3], 3'b000} == 32'hC0000040)? cpu0_io_byte_enable[0]: 1'b0),

    .mem_clk(clk_dram),
    .wr_addr(usb_ep2_wr_addr),
    .wr_data(usb_ep2_wr_data),
    .wr_en(usb_ep2_wr_en),
    .wr_push(usb_ep2_wr_push),
    .wr_full(usb_ep2_wr_full),
    .rd_data(usb_ep2_rd_data),
    .rd_pull(usb_ep2_rd_pull),
    .rd_empty(usb_ep2_rd_empty)
    );

always @(*) begin
    usb0_handshake = 2'b01;
    usb_mem0_bank_usb = 1'bx;
    usb_mem0_bank_in = 1'bx;
    usb_mem0_bank_out = 1'bx;
    usb0_in_data_valid = 1'b0;
    usb0_toggle = 1'bx;
    usb0_data_in = 8'hxx;
    case (usb0_endpoint)
        4'd0: begin
            usb0_toggle = usb_ep0_toggle;
            usb0_handshake = usb_ep0_handshake;
            usb_mem0_bank_usb = usb_ep0_bank_usb;
            usb_mem0_bank_in = usb_ep0_bank_in;
            usb_mem0_bank_out = usb_ep0_bank_out;
            usb0_in_data_valid = usb_ep0_in_data_valid;
            usb0_data_in = usb_mem0_douta;
        end
        4'd1: begin
            usb0_toggle = usb_ep1_toggle;
            usb0_handshake = usb_ep1_handshake;
            usb_mem0_bank_usb = usb_ep1_bank_usb;
            usb_mem0_bank_in = usb_ep1_bank_in;
            usb_mem0_bank_out = usb_ep1_bank_out;
            usb0_in_data_valid = usb_ep1_in_data_valid;
            usb0_data_in = usb_mem0_douta;
        end
        4'd2: begin
            usb0_toggle = usb_ep2_toggle;
            usb0_handshake = usb_ep2_handshake;
            usb0_in_data_valid = usb_ep2_in_data_valid;
            usb0_data_in = usb_ep2_in_data;
        end
    endcase
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        io_usb_attach <= 1'b0;
        io_usb_reset_flag <= 1'b0;
    end else begin
        if (cpu0_io_addr_strobe && cpu0_io_write_strobe) begin
            case ({cpu0_io_address[31:2], 2'b00})
                32'hC0000008: begin
                    io_usb_attach <= cpu0_io_write_data[0];
                    if (cpu0_io_write_data[2])
                        io_usb_reset_flag <= 1'b0;
                end
                32'hC000000C: begin
                    io_usb_address <= cpu0_io_write_data[6:0];
                end
            endcase
        end

        if (!usb0_transaction_active) begin
            io_usb_addr_ptr <= 1'b0;
        end else if (usb0_data_strobe) begin
            if (!io_usb_addr_ptr[6])
                io_usb_addr_ptr <= io_usb_addr_ptr + 1'b1;
        end

        if (usb_rst)
            io_usb_reset_flag <= 1'b1;
    end
end

//---------------------------------------------------------------------
// LED drivers
assign led = io_ledbits;

//---------------------------------------------------------------------
// DNA

reg[56:0] dna0_value;
reg dna0_ready;

assign io_dna = { dna0_ready, 6'b0, dna0_value };

reg dna0_clk;
reg[1:0] dna0_read;
wire dna0_dout;
wire dna0_shift = !dna0_ready && dna0_read == 2'b0;

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        dna0_clk <= 1'b0;
        dna0_value <= 57'h100000000000000;
        dna0_read <= 2'b10;
        dna0_ready <= 1'b0;
    end else if (strobe_4mhz) begin
        if (dna0_clk) begin
            dna0_read <= { 1'b0, dna0_read[1] };
            if (dna0_shift) begin
                dna0_ready <= dna0_value[0];
                dna0_value <= { dna0_dout, dna0_value[56:1] };
            end
        end
        dna0_clk <= !dna0_clk;
    end
end

DNA_PORT dna0(
    .DOUT(dna0_dout),
    .DIN(1'b0),
    .READ(dna0_read[0]),
    .SHIFT(dna0_shift),
    .CLK(dna0_clk)
    );

// 1Hz strobe generator
reg[25:0] clk_prescaler;
assign strobe_1hz = (clk_prescaler == 48000000);
always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        clk_prescaler <= 1'b0;
    end else begin
        if (strobe_1hz)
            clk_prescaler <= 1'b0;
        else
            clk_prescaler <= clk_prescaler + 1'b1;
    end
end

// 4MHz strobe generator
reg[3:0] clk_4mhz_prescaler;
assign strobe_4mhz = (clk_4mhz_prescaler == 11);
always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        clk_4mhz_prescaler <= 1'b0;
    end else begin
        if (strobe_4mhz)
            clk_4mhz_prescaler <= 1'b0;
        else
            clk_4mhz_prescaler <= clk_4mhz_prescaler + 1'b1;
    end
end

wire end_of_startup;
wire clk0_locked;
clock_controller clk0(
    .rst(!end_of_startup),
    .clk_33(clk_33),
    .clk_48(clk_48),
    .clk_dram(clk_dram),
    .clk_dram_out(clk_dram_out),
    .clk_dram_out_n(clk_dram_out_n),
    .clk_sampler(clk_sampler),
    .locked(clk0_locked)
    );
assign rst_n = end_of_startup && clk0_locked;

// Reset generator
STARTUP_SPARTAN6 startup0(
    .CFGCLK(),
    .CFGMCLK(),
    .CLK(),
    .EOS(end_of_startup),
    .GSR(),
    .GTS(),
    .KEYCLEARB()
    );

endmodule
