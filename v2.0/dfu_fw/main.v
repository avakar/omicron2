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
    input spi_miso
    );

wire rst_n;
wire clk_48;
wire strobe_1hz;
wire strobe_4mhz;

assign vio33 = 1'b0;
assign vio50 = 1'b0;

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

/* 32'hC0001000 */ wire[31:0] io_usb_mem;


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
        cpu0_io_ready <= cpu0_io_read_latency_cnt;
        cpu0_io_read_latency_cnt <= cpu0_io_addr_strobe && (cpu0_io_read_strobe || cpu0_io_write_strobe);
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
        32'hC0001???: cpu0_io_read_data <= io_usb_mem;
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
wire[7:0] usb0_data_in;
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
usb_mem usb_mem0(
    .clka(clk_48),
    .wea(usb0_transaction_active && !usb0_direction_in && usb0_data_strobe && !io_usb_addr_ptr[6]),
    .addra({ usb_mem0_bank_usb, usb0_endpoint[0], usb0_direction_in, io_usb_addr_ptr[5:0] }),
    .dina(usb0_data_out),
    .douta(usb0_data_in),

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

always @(*) begin
    case (usb0_endpoint)
        4'd0: begin
            usb0_toggle = usb_ep0_toggle;
            usb0_handshake = usb_ep0_handshake;
            usb_mem0_bank_usb = usb_ep0_bank_usb;
            usb_mem0_bank_in = usb_ep0_bank_in;
            usb_mem0_bank_out = usb_ep0_bank_out;
            usb0_in_data_valid = usb_ep0_in_data_valid;
        end
        4'd1: begin
            usb0_toggle = usb_ep1_toggle;
            usb0_handshake = usb_ep1_handshake;
            usb_mem0_bank_usb = usb_ep1_bank_usb;
            usb_mem0_bank_in = usb_ep1_bank_in;
            usb_mem0_bank_out = usb_ep1_bank_out;
            usb0_in_data_valid = usb_ep1_in_data_valid;
        end
        default: begin
            usb0_handshake = 2'b01;
            usb_mem0_bank_usb = 1'bx;
            usb_mem0_bank_in = 1'bx;
            usb_mem0_bank_out = 1'bx;
            usb0_in_data_valid = 1'b0;
            usb0_toggle = 1'bx;
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

// 48MHz generator
wire end_of_startup;
wire clk0_locked;
clock_controller clk0(
    .rst_n(end_of_startup),
    .clk_33(clk_33),
    .clk_48(clk_48),
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