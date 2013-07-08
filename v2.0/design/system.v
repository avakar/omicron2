module axi_to_io(
    input rst_n,
    input clk,

    input avalid,
    output aready,
    input awe,
    input[31:2] aaddr,
    input[31:0] adata,
    input[3:0] astrb,
    output bvalid,
    output[31:0] bdata,

    output io_addr_strobe,
    output io_read_strobe,
    output io_write_strobe,
    output[31:0] io_addr,
    output[3:0] io_byte_enable,
    output[31:0] io_write_data,
    input[31:0] io_read_data,
    input io_ready
    );

reg active;

assign aready = rst_n && !active;
assign bvalid = io_ready;
assign bdata = io_read_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        active <= 1'b0;
    end else begin
        if (avalid && aready)
            active <= 1'b1;
        if (bvalid)
            active <= 1'b0;
    end
end

assign io_addr_strobe = avalid && aready;
assign io_read_strobe = avalid && aready && !awe;
assign io_write_strobe = avalid && aready && awe;
assign io_addr = { aaddr, 2'b00 };
assign io_byte_enable = astrb;
assign io_write_data = adata;

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

wire avalid;
reg aready;
wire awe;
wire[31:2] aaddr;
wire[31:0] adata;
wire[3:0] astrb;
wire bvalid;
reg[31:0] bdata;

axi_cpu cpu0(
    .rst_n(rst_n),
    .clk(clk_48),

    .avalid(avalid),
    .aready(aready),
    .awe(awe),
    .aaddr(aaddr),
    .adata(adata),
    .astrb(astrb),
    .bvalid(bvalid),
    .bdata(bdata)
    );

wire io0_sel;
wire io0_aready;
wire io0_bvalid;
wire[31:0] io0_bdata;
axi_to_io io0(
    .rst_n(rst_n),
    .clk(clk_48),

    .avalid(avalid && io0_sel),
    .aready(io0_aready),
    .awe(awe),
    .aaddr(aaddr),
    .adata(adata),
    .astrb(astrb),
    .bvalid(io0_bvalid),
    .bdata(io0_bdata),

    .io_addr_strobe(io_addr_strobe),
    .io_read_strobe(io_read_strobe),
    .io_write_strobe(io_write_strobe),
    .io_addr(io_addr),
    .io_byte_enable(io_byte_enable),
    .io_write_data(io_write_data),
    .io_read_data(io_read_data),
    .io_ready(io_ready)
    );

wire dna0_sel;
wire dna0_aready;
wire dna0_bvalid;
wire[31:0] dna0_bdata;
axi_dna dna0(
    .rst_n(rst_n),
    .clk_48(clk_48),

    .avalid(avalid && dna0_sel),
    .aready(dna0_aready),
    .aaddr(aaddr[2:2]),
    .bvalid(dna0_bvalid),
    .bdata(dna0_bdata)
    );

//---------------------------------------------------------------------

assign dna0_sel = aaddr[31:3] == (32'hC2000000 >> 3);
assign io0_sel = !dna0_sel;

assign bvalid = io0_bvalid | dna0_bvalid;

always @(*) begin
    if (dna0_bvalid) begin
        bdata = dna0_bdata;
    end else begin
        bdata = io0_bdata;
    end
end

always @(*) begin
    if (dna0_sel) begin
        aready = dna0_aready;
    end else begin
        aready = io0_aready;
    end
end

endmodule
