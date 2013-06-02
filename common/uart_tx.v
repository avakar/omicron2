module uart_tx(
    input rst,
    input clk,
    input clken,
    input baud_x16_strobe,

    output reg txd,

    input[7:0] data,
    input valid,
    output ready
    );

reg[8:0] shift_reg;
reg[3:0] cnt;
assign ready = baud_x16_strobe && (shift_reg == 1'b0) && (cnt == 1'b0);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        txd <= 1'b1;
        shift_reg <= 1'b0;
        cnt <= 1'b0;
    end else if (clken && baud_x16_strobe) begin
        if (ready && valid) begin
            txd <= 1'b0;
            shift_reg <= { 1'b1, data };
            cnt <= 4'd15;
        end

        if (!ready)
            cnt <= cnt - 1'b1;

        if (!ready && cnt == 1'b0) begin
            txd <= shift_reg[0];
            shift_reg <= { 1'b0, shift_reg[8:1] };
        end
    end
end

endmodule
