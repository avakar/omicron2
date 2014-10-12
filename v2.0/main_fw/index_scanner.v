module index_scanner #(
    parameter width = 60
    )(
    input rst_n,
    input clk,

    input[15:0] sample,
    input sample_strobe,

    output reg[width-1:0] index,
    output[17:0] compressor_state,

    input clear_state
    );

reg[15:0] last_sample;
reg[1:0] state;

assign compressor_state = { last_sample, state };

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        last_sample <= 1'sbx;
        state <= 1'b0;
        index <= 1'b0;
    end else begin
        if (sample_strobe) begin
            last_sample <= sample;

            case (state)
                2'b00: begin
                    index <= index + 1'b1;
                    state <= 2'b01;
                end
                2'b01: begin
                    index <= index + 1'b1;
                    if (last_sample == sample)
                        state <= 2'b10;
                end
                2'b10: begin
                    index <= index + sample;
                    if (sample != 16'hffff)
                        state <= 2'b00;
                end
            endcase
        end

        if (clear_state)
            state <= 2'b00;
    end
end

endmodule
