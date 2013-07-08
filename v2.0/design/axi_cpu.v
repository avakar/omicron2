module axi_cpu(
    input rst_n,
    input clk,

    output avalid,
    input aready,
    output awe,
    output[31:2] aaddr,
    output[31:0] adata,
    output[3:0] astrb,
    input bvalid,
    input[31:0] bdata
    );

wire io_addr_strobe, io_read_strobe, io_write_strobe;
wire[31:0] io_addr, io_write_data;
wire[3:0] io_byte_enable;
cpu cpu0(
    .Clk(clk),
    .Reset(!rst_n),

    .IO_Addr_Strobe(io_addr_strobe),
    .IO_Read_Strobe(io_read_strobe),
    .IO_Write_Strobe(io_write_strobe),
    .IO_Address(io_addr),
    .IO_Byte_Enable(io_byte_enable),
    .IO_Write_Data(io_write_data),
    .IO_Read_Data(bdata),
    .IO_Ready(bvalid)
);

wire wr = io_addr_strobe && io_write_strobe;
wire rd = io_addr_strobe && io_read_strobe;

reg avalid_hold;
reg awe_hold;
reg[31:2] aaddr_hold;
reg[31:0] adata_hold;
reg[3:0] astrb_hold;

assign avalid = rd || wr || avalid_hold;
assign awe = wr || awe_hold;
assign aaddr = avalid_hold? aaddr_hold: io_addr[31:2];
assign adata = avalid_hold? adata_hold: io_write_data;
assign astrb = avalid_hold? astrb_hold: io_byte_enable;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        avalid_hold <= 1'b0;
    end else begin
        if (!avalid_hold) begin
            awe_hold <= wr;
            aaddr_hold <= io_addr[31:2];
            adata_hold <= io_write_data;
            astrb_hold <= io_byte_enable;
        end

        avalid_hold <= avalid && !aready;
    end
end

endmodule
