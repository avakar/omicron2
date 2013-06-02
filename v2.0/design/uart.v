module uart(
    input rst,
    input clk_48,

    input rxd,
    output txd,

    input[7:0] tx_data,
    input tx_data_valid,
    output tx_data_ready,

    output[7:0] rx_data,
    output rx_data_valid,
    output rx_overflow_error,
    output rx_frame_error,
    input rx_data_ready
    );

reg[6:0] baud_cnt;
wire baud_strobe = (baud_cnt == 1'b0);
always @(posedge clk_48) begin
    if (baud_cnt == 1'b0)
        baud_cnt <= 7'd77;
    else
        baud_cnt <= baud_cnt - 1'b1;
end

uart_tx uart_tx0(
    .rst(rst),
    .clk(clk_48),
    .clken(1'b1),
    .baud_x16_strobe(baud_strobe),
    
    .txd(txd),

    .data(tx_data),
    .valid(tx_data_valid),
    .ready(tx_data_ready)
    );

uart_rx uart_rx0(
    .rst(rst),
    .clk(clk_48),
    .clken(1'b1),
    .baud_x16_strobe(baud_strobe),

    .rxd(rxd),

    .data(rx_data),
    .overflow_error(rx_overflow_error),
    .frame_error(rx_frame_error),
    .valid(rx_data_valid),
    .ready(1'b1)
    );

endmodule
