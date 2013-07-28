module spi(
    input rst_n,
    input clk,

    input avalid,
    input awe,
    input[7:0] adata,
    input[0:0] aaddr,
    output reg bvalid,
    output reg[7:0] bdata,

    output reg spi_cs,
    output reg spi_clk,
    output reg spi_mosi,
    input spi_miso
    );

reg[7:0] data_out;
reg[7:0] data_in;
reg[3:0] data_cnt;

wire half_strobe = 1'b1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spi_cs <= 1'b1;
        spi_clk <= 1'b1;
        spi_mosi <= 1'b1;
        data_out <= 1'b0;
        data_in <= 1'b0;
        data_cnt <= 1'b0;
        bvalid <= 1'b0;
        bdata <= 1'sbx;
    end else begin
        bdata <= 1'sbx;
        bvalid <= avalid;

        if (avalid && awe) begin
            case (aaddr)
                1'd0: begin
                    spi_cs <= adata[0];
                end
                1'd1: begin
                    data_out <= adata;
                    data_cnt <= 4'd8;
                end
            endcase
        end

        if (avalid && !awe) begin
            case (aaddr)
                1'd0: begin
                    bdata <= { 6'b0, data_cnt || !spi_clk, spi_cs };
                end
                1'd1: begin
                    bdata <= data_in;
                end
            endcase
        end

        if (half_strobe && spi_clk && data_cnt) begin
            spi_mosi <= data_out[7];
            data_out <= { data_out[6:0], 1'b0 };
            spi_clk <= 1'b0;
            data_cnt <= data_cnt - 1'b1;
        end

        if (half_strobe && !spi_clk) begin
            data_in <= { data_in[6:0], spi_miso };
            spi_clk <= 1'b1;
        end
    end
end

endmodule
