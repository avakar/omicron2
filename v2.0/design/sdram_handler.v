module sdram_handler(
    input rst_n,
    input clk,

    output w_en,
    input[15:0] w_data,
    input w_empty,

    output r_en,
    output[15:0] r_data,
    input r_almost_full,

    input rprio,

    output m_clk_oe,
    output m_cs_n,
    output m_cke,
    output[12:0] m_a,
    output[1:0] m_ba,
    output m_ras_n,
    output m_cas_n,
    output m_we_n,
    output m_ldqm,
    output m_udqm,
    inout[15:0] m_dq,

    input avalid,
    input awe,
    input[2:2] aaddr,
    input[31:0] adata,
    output reg bvalid,
    output[31:0] bdata
    );

assign m_cs_n = 1'b0;

reg[23:0] waddr;
reg[23:0] raddr;
reg[11:0] rcount;

wire w_able = !w_empty;
wire r_able = rcount && !r_almost_full;
wire rsel = !w_able || rprio;
wire sdram0_avalid = r_able || w_able;
wire sdram0_awe = !rsel;

wire sdram0_aready;
wire sdram0_bvalid;
wire sdram0_bwe;
sdram sdram0(
    .rst(!rst_n),
    .clk(clk),

    .avalid(sdram0_avalid),
    .aready(sdram0_aready),
    .awe(sdram0_awe),
    .aaddr(rsel? raddr: waddr),
    .adata(w_data),
    .bvalid(sdram0_bvalid),
    .bwe(sdram0_bwe),
    .bdata(r_data),

    .m_clk_oe(m_clk_oe),
    .m_cke(m_cke),
    .m_ras(m_ras_n),
    .m_cas(m_cas_n),
    .m_we(m_we_n),
    .m_ba(m_ba),
    .m_a(m_a),
    .m_dqm({m_udqm, m_ldqm}),
    .m_dq(m_dq)
    );

assign w_en = sdram0_avalid && sdram0_aready && sdram0_awe;
assign r_en = sdram0_bvalid && !sdram0_bwe;

assign bdata = { w_able, 7'b0, waddr };

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        waddr <= 1'b0;
        raddr <= 1'b0;
        rcount <= 1'b0;
        bvalid <= 1'b0;
    end else begin
        if (w_en)
            waddr <= waddr + 1'b1;

        if (sdram0_avalid && sdram0_aready && !sdram0_awe) begin
            raddr <= raddr + 1'b1;
            rcount <= rcount - 1'b1;
        end

        if (avalid && awe) begin
            case (aaddr)
                1'h0: begin
                    raddr <= adata;
                end
                1'h1: begin
                    rcount <= adata;
                end
            endcase
        end

        bvalid <= avalid;
    end
end

endmodule
