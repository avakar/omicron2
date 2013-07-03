module axi_async_w #(
    parameter aw = 4,
    parameter w = 32
    )(
    input rst_n,

    input clka,
    input wvalida,
    output wreadya,
    input[aw-1:0] waddra,
    input[w-1:0] wdataa,

    input clkb,
    output wvalidb,
    input wreadyb,
    output reg[aw-1:0] waddrb,
    output reg[w-1:0] wdatab
    );

reg[2:0] avalid;
reg[2:0] aready;

always @(posedge clka or negedge rst_n) begin
    if (!rst_n) begin
        aready[2:1] <= 2'b00;
        avalid[0] <= 1'b0;
    end else begin
        aready[2:1] <= aready[1:0];
        
        if (wreadya && wvalida) begin
            avalid[0] <= !avalid[0];
            waddrb <= waddra;
            wdatab <= wdataa;
        end
    end
end

always @(posedge clkb or negedge rst_n) begin
    if (!rst_n) begin
        avalid[2:1] <= 2'b00;
        aready[0] <= 1'b0;
    end else begin
        avalid[2:1] <= avalid[1:0];
        
        if (wvalidb && wreadyb) begin
            aready[0] <= !aready[0];
        end
    end
end

assign wreadya = (avalid[0] == aready[2]);
assign wvalidb = (avalid[2] != aready[0]);

endmodule
