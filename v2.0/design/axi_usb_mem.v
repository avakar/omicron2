module axi_usb_mem(
    input rst_n,
    input clk,

    input avalid,
    input awe,
    input[9:2] aaddr,
    input[31:0] adata,
    input[3:0] astrb,
    output reg bvalid,
    output[31:0] bdata,

    input mem_we,
    input[9:0] mem_addr,
    input[7:0] mem_write_data,
    output[7:0] mem_read_data
    );

usb_ram usb_ram0(
    .clka(clk),
    .wea(mem_we),
    .addra(mem_addr),
    .dina(mem_write_data),
    .douta(mem_read_data),

    .clkb(clk),
    .web(avalid && awe? astrb: 1'b0),
    .addrb(aaddr),
    .dinb(adata),
    .doutb(bdata)
    );

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bvalid <= 1'b0;
    end else begin
        bvalid <= avalid;
    end
end

endmodule
