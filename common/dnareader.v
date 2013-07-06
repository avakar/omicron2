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

module axi_dna(
    input rst_n,
    input clk_48,

    input arvalid,
    input[2:2] araddr,

    output reg rvalid,
    output reg[31:0] rdata
    );

wire[56:0] dna;
wire dna_ready;
dnareader dna0(
    .rst(!rst_n),
    .clk_48(clk_48),
    .dna(dna),
    .ready(dna_ready)
    );

reg addr_sel;

always @(*) begin
    case (addr_sel)
        1'd0: rdata = dna[31:0];
        1'd1: rdata = { dna_ready, 6'b0, dna[56:32] };
    endcase
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        rvalid <= 1'b0;
    end else begin
        rvalid <= 1'b0;
        if (arvalid) begin
            addr_sel <= araddr;
            rvalid <= 1'b1;
        end
    end
end

endmodule
