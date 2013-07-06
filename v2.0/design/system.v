module system(
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

wire axi0_wvalid;
wire axi0_wready;
wire[31:0] axi0_awaddr;
wire[31:0] axi0_wdata;
wire[3:0] axi0_wstrb;
wire axi0_bvalid;
wire axi0_arvalid;
wire axi0_arready;
wire[31:0] axi0_araddr;
wire axi0_rvalid;
wire[31:0] axi0_rdata;

axi_cpu cpu0(
    .rst_n(rst_n),
    .clk(clk),

    .wvalid(axi0_wvalid),
    .wready(axi0_wready),
    .awaddr(axi0_awaddr),
    .wdata(axi0_wdata),
    .wstrb(axi0_wstrb),

    .bvalid(axi0_bvalid),

    .arvalid(axi0_arvalid),
    .arready(axi0_arready),
    .araddr(axi0_araddr),

    .rvalid(axi0_rvalid),
    .rdata(axi0_rdata)
    );

reg read_active, write_active;

assign io_byte_enable = axi0_wstrb;
assign io_write_data = axi0_wdata;
assign io_addr = axi0_wvalid? axi0_awaddr: axi0_araddr;
assign axi0_wready = !read_active && !write_active;
assign axi0_arready = !read_active && !write_active && !axi0_wvalid;
assign axi0_rdata = io_read_data;
assign axi0_rvalid = read_active && io_ready;
assign axi0_bvalid = write_active && io_ready;

assign io_read_strobe = !read_active && !write_active && axi0_arvalid && !axi0_wvalid;
assign io_write_strobe = !read_active && !write_active && axi0_wvalid;
assign io_addr_strobe = io_read_strobe || io_write_strobe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_active <= 1'b0;
        write_active <= 1'b0;
    end else begin
        if (io_write_strobe)
            write_active <= 1'b1;
        if (io_read_strobe)
            read_active <= 1'b1;
        if (io_ready) begin
            read_active <= 1'b0;
            write_active <= 1'b0;
        end
    end
end

endmodule
