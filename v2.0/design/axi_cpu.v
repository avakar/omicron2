module axi_cpu(
    input rst_n,
    input clk,

    output io_addr_strobe,
    output io_read_strobe,
    output io_write_strobe,

    output[31:0] io_addr,
    output[3:0] io_byte_enable,
    output[31:0] io_write_data,
    input[31:0] io_read_data,
    input io_ready
    );

cpu cpu0(
    .Clk(clk),
    .Reset(!rst_n),

    .IO_Addr_Strobe(io_addr_strobe),
    .IO_Read_Strobe(io_read_strobe),
    .IO_Write_Strobe(io_write_strobe),
    .IO_Address(io_addr),
    .IO_Byte_Enable(io_byte_enable),
    .IO_Write_Data(io_write_data),
    .IO_Read_Data(io_read_data),
    .IO_Ready(io_ready)
);

endmodule

/*module axi_cpu(
    input rst_n,
    input clk,

    output reg wvalid,
    input wready,
    output[31:0] awaddr,
    output reg[31:0] wdata,
    output reg[3:0] wstrb,

    input bvalid,

    output reg arvalid,
    input arready,
    output[31:0] araddr,

    input rvalid,
    input[31:0] rdata
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
    .IO_Read_Data(rdata),
    .IO_Ready(bvalid || rvalid)
);

reg[31:0] addr;
assign awaddr = addr;
assign araddr = addr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wvalid <= 1'b0;
        addr <= 1'sbx;
        wdata <= 1'sbx;
        wstrb <= 1'sbx;
        arvalid <= 1'b0;
    end else begin
        if (wready)
            wvalid <= 1'b0;

        if (io_addr_strobe)
            addr <= io_addr;

        if (io_addr_strobe && io_write_strobe) begin
            wvalid <= 1'b1;
            wdata <= io_write_data;
            wstrb <= io_byte_enable;
        end

        if (arready)
            arvalid <= 1'b0;

        if (io_addr_strobe && io_read_strobe)
            arvalid <= 1'b1;
    end
end

endmodule
*/