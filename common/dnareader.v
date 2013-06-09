module dnareader(
    input rst,
    input clk_48,
    output[56:0] dna,
    output reg ready
    );

reg clk_dna;
reg[55:0] dnar;
reg dna_read;
wire dna_out;
reg dna_shift;

assign dna = { dnar, dna_out };

DNA_PORT dna0(
    .CLK(clk_dna),
    .DOUT(dna_out),
    .DIN(1'b1),
    .READ(dna_read),
    .SHIFT(dna_shift && !ready)
    );

reg[3:0] clk_cnt;
always @(posedge clk_48 or posedge rst) begin
    if (rst) begin
        clk_cnt <= 4'd15;
        clk_dna <= 1'b0;
        dnar <= 1'sbx;
        dna_read <= 1'b0;
        dna_shift <= 1'b0;
        ready <= 1'b0;
    end else if (!ready) begin
        clk_cnt <= clk_cnt - 1'b1;
        if (!clk_cnt) begin
            clk_dna <= !clk_dna;
            if (clk_dna) begin
                if (!dna_shift && !dna_read)
                    dna_read <= 1'b1;

                if (!dna_shift && dna_read) begin
                    dna_read <= 1'b0;
                    dna_shift <= 1'b1;
                    dnar <= 1'b1;
                end

                dnar <= { dnar[54:0], dna_out };
                ready <= dnar[55];
            end
        end
    end
end



endmodule
