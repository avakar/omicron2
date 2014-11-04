module uart_rx #(
    parameter w = 8,
    parameter ss = 16
    )(
    input rst,
    input clk,
    input clken,

    input rxd,
    input strobe,

    output reg[w-1:0] data,
    output reg overflow_error,
    output reg frame_error,
    output reg valid,
    input ready
    );

localparam ss_mid = (ss + 1) / 2 - 1;

reg[w:0] shift_reg;
wire receiving = &{rxd, shift_reg} == 1'b0;

reg[$clog2(ss)-1:0] strobe_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        strobe_cnt <= ss_mid;
    end else if (clken && strobe) begin
        if (receiving) begin
            if (strobe_cnt == 1'b0)
                strobe_cnt <= ss - 1;
            else
                strobe_cnt <= strobe_cnt - 1'b1;
        end else begin
            strobe_cnt <= ss_mid;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        data <= 1'b0;
        frame_error <= 1'b0;
        overflow_error <= 1'b0;
        valid <= 1'b0;
        shift_reg <= 1'sb1;
    end else if (clken) begin
        if (valid && ready)
            valid <= 1'b0;

        if (strobe && strobe_cnt == 1'b0) begin
            if (shift_reg[0] == 1'b0) begin
                data <= shift_reg[w:1];
                frame_error <= !rxd;
                overflow_error <= valid;
                valid <= 1'b1;
                shift_reg <= 1'sb1;
            end else begin
                shift_reg <= { rxd, shift_reg[w:1] };
            end
        end
    end
end

endmodule
