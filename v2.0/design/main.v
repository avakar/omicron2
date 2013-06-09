module main(
    input rst_n,
    input clk_33,
    output[2:0] led,
    inout[15:0] s,
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
    inout usb_dn
    );

wire clk_48;
clock_controller clkctrl(
    .rst(1'b0),
    .clk_33(clk_33),
    .clk_48(clk_48)
    );

reg[25:0] counter;
wire blink_strobe = (counter == 1'b0);
always @(posedge clk_48) begin
    if (counter == 1'b0)
        counter <= 26'd48000000;
    else
        counter <= counter - 1'b1;
end

reg[2:0] debug_snake;
always @(posedge clk_48) begin
    if (blink_strobe)
        debug_snake <= { debug_snake[1], debug_snake[0], !debug_snake[2] };
end

spiviajtag spiviajtag0(
    .clk(flash_clk),
    .cs_n(flash_cs),
    .mosi(flash_si),
    .miso(flash_so)
);

/*reg[7:0] tx_buf;
reg tx_buf_valid;
wire tx_buf_ready;
wire[7:0] rx_buf;
wire rx_buf_valid;
uart uart0(
    .rst(1'b0),
    .clk_48(clk_48),

    .rxd(rxd),
    .txd(txd),

    .tx_data(tx_buf),
    .tx_data_valid(tx_buf_valid),
    .tx_data_ready(tx_buf_ready),

    .rx_data(rx_buf),
    .rx_data_valid(rx_buf_valid),
    .rx_frame_error()
    );

always @(posedge clk_48) begin
    if (tx_buf_ready)
        tx_buf_valid <= 1'b0;

    if (rx_buf_valid) begin
        tx_buf <= rx_buf + 1'b1;
        tx_buf_valid <= 1'b1;
    end
end*/

wire[31:0] io_addr;
reg[31:0] io_read_data;
wire[31:0] io_write_data;
reg io_ready;
wire io_write_strobe, io_read_strobe, io_addr_strobe;
wire[3:0] io_byte_enable;

wire txd, rxd;
cpu cpu0(
  .Clk(clk_48),
  .Reset(!rst_n),

  .IO_Addr_Strobe(io_addr_strobe),
  .IO_Read_Strobe(io_read_strobe),
  .IO_Write_Strobe(io_write_strobe),
  .IO_Address(io_addr),
  .IO_Byte_Enable(io_byte_enable),
  .IO_Write_Data(io_write_data),
  .IO_Read_Data(io_read_data),
  .IO_Ready(io_ready),

  .UART_Rx(rxd),
  .UART_Tx(txd)
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
    .rst_n(rst_n),
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
    .wea(usb_data_strobe && !usb_addr_ptr[6]),
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

always @(*) begin
    casez (io_addr)
        32'hC0000000:
            io_read_data = { usb_addr_ptr, 6'b0, usb_reset_flag, usb_attach };
        32'hC0000004:
            io_read_data = usb_address;
        32'hC000010?:
            io_read_data = usb_ep0_ctrl_rd_data;
        32'hC000011?:
            io_read_data = usb_ep1_ctrl_rd_data;
        32'hC100????:
            io_read_data = usb_read_data_b;
        default:
            io_read_data = 32'sbx;
    endcase
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        io_ready <= 1'b0;
        usb_attach <= 1'b0;
        usb_address <= 6'b0;
        usb_reset_flag <= 1'b0;
        usb_reset_prev <= 1'b0;
        usb_addr_ptr <= 1'b0;
    end else begin
        usb_reset_prev <= usb_reset;

        if (usb_reset && !usb_reset_prev)
            usb_reset_flag <= 1'b1;

        if (!usb_transaction_active) begin
            usb_addr_ptr <= 1'b0;
        end else if (usb_data_strobe) begin
            if (!usb_addr_ptr[6])
                usb_addr_ptr <= usb_addr_ptr + 1'b1;
        end

        io_ready <= io_addr_strobe && (io_write_strobe || io_read_strobe);
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
            endcase
        end
    end
end

assign s  = { 8'bzzzzzzzz, txd, 7'bzzzzzzz };
assign sd = 16'b0000000010000000;
assign rxd = s[6];

assign vio_33 = 1'b1;
assign vio_50 = 1'b0;

assign led = debug_snake;

endmodule