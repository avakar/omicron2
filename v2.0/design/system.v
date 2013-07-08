module axi_sampler_fifo(
    input rst_n,
    input clk,

    input[15:0] in_data,
    input in_strobe,

    input avalid,
    output aready,
    input awe,
    input[2:2] aaddr,
    input[31:0] adata,
    output reg bvalid,
    output reg[31:0] bdata
    );

wire[15:0] fifo_rd_data;
wire fifo_empty;
reg fifo_rd;
sample_fifo s0_fifo(
    .rst(!rst_n),

    .wr_clk(clk),
    .din(in_data),
    .wr_en(in_strobe),

    .rd_clk(clk),
    .rd_en(fifo_rd),
    .dout(fifo_rd_data),
    .empty(fifo_empty),
    .full(),
    .overflow()
);

assign aready = bvalid;

always @(*) begin
    case (aaddr)
        1'd0: bdata = !fifo_empty;
        1'd1: bdata = fifo_rd_data;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_rd <= 1'b0;
        bvalid <= 1'b0;
    end else begin
        fifo_rd <= 1'b0;

        if (avalid && awe) begin
            if (aaddr == 1'd0 && adata[0])
                fifo_rd <= 1'b1;
        end

        bvalid <= avalid && !aready;
    end
end

endmodule

module system(
    input rst_n,
    input clk_48,

    input rx_j,
    input rx_se0,
    output tx_en,
    output tx_j,
    output tx_se0,
    output pup_en,

    input[15:0] s0_in_data,
    output s0_compressor_overflow_error
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

wire usb0_mem_we;
wire[9:0] usb0_mem_addr;
wire[7:0] usb0_mem_write_data;
wire[7:0] usb0_mem_read_data;

wire usb_mem0_sel;
wire usb_mem0_bvalid;
wire[31:0] usb_mem0_bdata;
axi_usb_mem usb_mem0(
    .rst_n(rst_n),
    .clk(clk_48),

    .avalid(avalid && usb_mem0_sel),
    .awe(awe),
    .aaddr(aaddr[9:2]),
    .adata(adata),
    .astrb(astrb),
    .bvalid(usb_mem0_bvalid),
    .bdata(usb_mem0_bdata),

    .mem_we(usb0_mem_we),
    .mem_addr(usb0_mem_addr),
    .mem_write_data(usb0_mem_write_data),
    .mem_read_data(usb0_mem_read_data)
    );

wire usb0_sel;
wire usb0_aready;
wire usb0_bvalid;
wire[31:0] usb0_bdata;
axi_usb usb0(
    .rst_n(rst_n),
    .clk_48(clk_48),

    .avalid(avalid && usb0_sel),
    .aready(usb0_aready),
    .awe(awe),
    .aaddr(aaddr[15:2]),
    .adata(adata),
    .bvalid(usb0_bvalid),
    .bdata(usb0_bdata),

    .rx_j(rx_j),
    .rx_se0(rx_se0),
    .tx_en(tx_en),
    .tx_j(tx_j),
    .tx_se0(tx_se0),
    .pup_en(pup_en),

    .mem_we(usb0_mem_we),
    .mem_addr(usb0_mem_addr),
    .mem_write_data(usb0_mem_write_data),
    .mem_read_data(usb0_mem_read_data)
    );

wire[15:0] s0_out_data;
wire s0_out_strobe;

wire s0_sel;
wire s0_bvalid;
wire[31:0] s0_bdata;
sampler s0(
    .clk(clk_48),
    .rst_n(rst_n),

    .s(s0_in_data),
    .out_data(s0_out_data),
    .out_valid(s0_out_strobe),
    .compressor_overflow_error(s0_compressor_overflow_error),

    .avalid(avalid && s0_sel),
    .awe(awe),
    .aaddr(aaddr[4:2]),
    .adata(adata),
    .bvalid(s0_bvalid),
    .bdata(s0_bdata)
    );

wire s0_fifo_sel;
wire s0_fifo_aready;
wire s0_fifo_bvalid;
wire[31:0] s0_fifo_bdata;
axi_sampler_fifo s0_fifo(
    .rst_n(rst_n),
    .clk(clk_48),

    .in_data(s0_out_data),
    .in_strobe(s0_out_strobe),

    .avalid(avalid && s0_fifo_sel),
    .aready(s0_fifo_aready),
    .awe(awe),
    .aaddr(aaddr[2:2]),
    .adata(adata),
    .bvalid(s0_fifo_bvalid),
    .bdata(s0_fifo_bdata)
    );

//---------------------------------------------------------------------

assign dna0_sel = aaddr[31:3] == (32'hC2000000 >> 3);
assign usb_mem0_sel = aaddr[31:16] == 32'hC100;
assign usb0_sel = aaddr[31:16] == 32'hC000;
assign s0_sel = aaddr[31:8] == 24'hC20001;
assign s0_fifo_sel = aaddr[31:3] == (32'hC2000010 >> 3);
wire fallback_sel = !s0_fifo_sel && !s0_sel && !usb0_sel && !usb_mem0_sel && !dna0_sel;

reg fallback_bvalid;
assign bvalid = fallback_bvalid || dna0_bvalid || usb_mem0_bvalid || usb0_bvalid || s0_bvalid || s0_fifo_bvalid;

always @(*) begin
    if (dna0_bvalid) begin
        bdata = dna0_bdata;
    end else if (usb_mem0_bvalid) begin
        bdata = usb_mem0_bdata;
    end else if (usb0_bvalid) begin
        bdata = usb0_bdata;
    end else if (s0_bvalid) begin
        bdata = s0_bdata;
    end else if (s0_fifo_bvalid) begin
        bdata = s0_fifo_bdata;
    end else begin
        bdata = 1'b0;
    end
end

always @(*) begin
    if (dna0_sel) begin
        aready = dna0_aready;
    end else if (usb_mem0_sel || s0_sel) begin
        aready = 1'b1;
    end else if (usb0_sel) begin
        aready = usb0_aready;
    end else if (s0_fifo_sel) begin
        aready = s0_fifo_aready;
    end else begin
        aready = 1'b1;
    end
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        fallback_bvalid <= 1'b0;
    end else begin
        fallback_bvalid <= avalid && fallback_sel;
    end
end

endmodule
