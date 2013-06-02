module main(
    input clk_33,
    output[2:0] led,
    inout[15:0] s,
    output[15:0] sd,

    output vio_33,
    output vio_50,

    output flash_cs,
    output flash_si,
    output flash_clk,
    input flash_so
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
wire[31:0] io_read_data = 1'b0;
wire[31:0] io_write_data;
wire io_ready = 1'b0;
wire io_write_strobe, io_read_strobe, io_addr_strobe;

wire txd, rxd;
cpu cpu0(
  .Clk(clk_48),
  .Reset(1'b0),

  .IO_Addr_Strobe(io_addr_strobe),
  .IO_Read_Strobe(io_read_strobe),
  .IO_Write_Strobe(io_write_strobe),
  .IO_Address(io_addr),
  .IO_Byte_Enable(),
  .IO_Write_Data(io_write_data),
  .IO_Read_Data(io_read_data),
  .IO_Ready(io_ready),

  .UART_Rx(rxd),
  .UART_Tx(txd)
);

assign s  = { 8'bzzzzzzzz, txd, 7'bzzzzzzz };
assign sd = 16'b0000000010000000;
assign rxd = s[6];

assign vio_33 = 1'b1;
assign vio_50 = 1'b0;

assign led = debug_snake;

endmodule
