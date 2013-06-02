module uart_rx(
    input rst,
    input clk,
    input clken,
    input baud_x16_strobe,

    input rxd,

    output reg[7:0] data,
    output reg overflow_error,
    output reg frame_error,
    output reg valid,
    input ready
    );

reg[1:0] prev_samples;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev_samples <= 1'sb1;
    end else if (clken && baud_x16_strobe) begin
        prev_samples <= { prev_samples[0], rxd };
    end
end

reg multisample;
always @(*) begin
    case ({ prev_samples, rxd })
        3'b000: multisample = 1'b0;
        3'b001: multisample = 1'b0;
        3'b010: multisample = 1'b0;
        3'b011: multisample = 1'b1;
        3'b100: multisample = 1'b0;
        3'b101: multisample = 1'b1;
        3'b110: multisample = 1'b1;
        3'b111: multisample = 1'b1;
    endcase
end

reg[8:0] shift_reg;
wire receiving = multisample == 1'b0 || shift_reg != 9'b111111111;

reg[3:0] strobe_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        strobe_cnt <= 4'd7;
    end else if (clken && baud_x16_strobe) begin
        if (receiving)
            strobe_cnt <= strobe_cnt - 1'b1;
        else
            strobe_cnt <= 4'd7;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        data <= 1'b0;
        frame_error <= 1'b0;
        overflow_error <= 1'b0;
        valid <= 1'b0;
        shift_reg <= 9'b111111111;
    end else if (clken) begin
        if (valid && ready)
            valid <= 1'b0;

        if (baud_x16_strobe && strobe_cnt == 1'b0) begin
            if (shift_reg[0] == 1'b0) begin
                data <= shift_reg[8:1];
                frame_error <= !multisample;
                overflow_error <= valid;
                valid <= 1'b1;
                shift_reg <= 9'b111111111;
            end else begin
                shift_reg <= { multisample, shift_reg[8:1] };
            end
        end
    end
end

endmodule
