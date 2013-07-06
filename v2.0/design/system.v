module axi_to_io(
    input rst_n,
    input clk,

    input wvalid,
    output wready,
    input[31:0] awaddr,
    input[31:0] wdata,
    input[3:0] wstrb,
    output bvalid,
    input arvalid,
    output arready,
    input[31:0] araddr,
    output rvalid,
    output[31:0] rdata,

    output io_addr_strobe,
    output io_read_strobe,
    output io_write_strobe,
    output[31:0] io_addr,
    output[3:0] io_byte_enable,
    output[31:0] io_write_data,
    input[31:0] io_read_data,
    input io_ready
    );

reg read_active, write_active;

assign io_byte_enable = wstrb;
assign io_write_data = wdata;
assign io_addr = wvalid? awaddr: araddr;
assign wready = !read_active && !write_active;
assign arready = !read_active && !write_active && !wvalid;
assign rdata = io_read_data;
assign rvalid = read_active && io_ready;
assign bvalid = write_active && io_ready;

assign io_read_strobe = !read_active && !write_active && arvalid && !wvalid;
assign io_write_strobe = !read_active && !write_active && wvalid;
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

module system(
    input rst_n,
    input clk_48,

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
reg axi0_wready;
wire[31:0] axi0_awaddr;
wire[31:0] axi0_wdata;
wire[3:0] axi0_wstrb;
wire axi0_bvalid;
wire axi0_arvalid;
reg axi0_arready;
wire[31:0] axi0_araddr;
wire axi0_rvalid;
reg[31:0] axi0_rdata;

axi_cpu cpu0(
    .rst_n(rst_n),
    .clk(clk_48),

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

wire io0_bvalid, io0_rvalid, io0_wready, io0_arready;
wire[31:0] io0_rdata;
axi_to_io io0(
    .rst_n(rst_n),
    .clk(clk_48),

    .wvalid(axi0_wvalid),
    .wready(io0_wready),
    .awaddr(axi0_awaddr),
    .wdata(axi0_wdata),
    .wstrb(axi0_wstrb),
    .bvalid(io0_bvalid),
    .arvalid(axi0_arvalid),
    .arready(io0_arready),
    .araddr(axi0_araddr),
    .rvalid(io0_rvalid),
    .rdata(io0_rdata),

    .io_addr_strobe(io_addr_strobe),
    .io_read_strobe(io_read_strobe),
    .io_write_strobe(io_write_strobe),
    .io_addr(io_addr),
    .io_byte_enable(io_byte_enable),
    .io_write_data(io_write_data),
    .io_read_data(io_read_data),
    .io_ready(io_ready)
    );

//---------------------------------------------------------------------

assign axi0_rvalid = io0_rvalid;

assign axi0_bvalid = io0_bvalid;

always @(*) begin
    axi0_wready = io0_wready;
end

always @(*) begin
    axi0_arready = io0_arready;
    axi0_rdata = io0_rdata;
end

//---------------------------------------------------------------------

/*wire usb0_wready;
wire usb0_arready;
wire usb0_rvalid;
wire[31:0] usb0_rdata;
axi_usb usb0(
    .rst_n(rst_n),
    .clk_48(clk_48),

    .rx_j(usb0_rx_j),
    .rx_se0(usb0_rx_se0),
    .tx_en(usb0_tx_en),
    .tx_j(usb0_tx_j),
    .tx_se0(usb0_tx_se0),

    .awaddr(axi0_awaddr[7:0]),
    .wdata(axi0_wdata),
    .wvalid(axi0_wvalid && axi0_awaddr[31:8] == 24'hC00000),
    .wready(usb0_wready),

    .araddr(axi0_araddr),
    .arvalid(axi0_arvalid && axi0_araddr[31:8] == 24'hC00000),
    .arready(usb0_arready),
    .rdata(usb0_rdata),
    .rvalid(usb0_rvalid)
    );*/

endmodule
