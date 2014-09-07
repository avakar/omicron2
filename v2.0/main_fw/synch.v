module synch #(
    parameter w = 1,
    parameter d = 2
    )(
    input clk,
    input[w-1:0] i,
    output[w-1:0] o
    );

reg[w-1:0] r[d-1:0];
assign o = r[0];

genvar x;
generate
    for (x = 1; x < d; x = x + 1) begin : g
        always @(posedge clk) r[x-1] <= r[x];
    end
endgenerate

always @(posedge clk) r[d-1] <= i;

endmodule
