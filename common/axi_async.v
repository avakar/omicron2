module aaxi_async_bridge(
    input rst_n,

    input s_clk,
    input s_avalid,
    input s_awe,
    input[31:2] s_aaddr,
    input[31:0] s_adata,
    input[3:0] s_astrb,
    output reg s_bvalid,
    output reg[31:0] s_bdata,

    input m_clk,
    output reg m_avalid,
    input m_aready,
    output reg m_awe,
    output reg[31:2] m_aaddr,
    output reg[31:0] m_adata,
    output reg[3:0] m_astrb,
    input m_bvalid,
    input[31:0] m_bdata
    );

reg awe;
reg[31:2] aaddr;
reg[31:0] adata;
reg[3:0] astrb;

reg s_avalid_hold;
reg[1:0] m_avalid_hold;
reg m_aready_hold;
reg[1:0] s_aready_hold;

reg s_active;
reg m_active;

reg[31:0] m_bdata_hold;

always @(posedge s_clk or negedge rst_n) begin
    if (!rst_n) begin
        s_active <= 1'b0;
        s_avalid_hold <= 1'b0;
        s_aready_hold <= 2'b00;
        s_bvalid <= 1'b0;
    end else begin
        s_bvalid <= 1'b0;

        if (!s_active && s_avalid) begin
            s_avalid_hold <= !s_avalid_hold;
            s_active <= 1'b1;
            awe <= s_awe;
            aaddr <= s_aaddr;
            adata <= s_adata;
            astrb <= s_astrb;
        end
        
        if (s_active && (s_avalid_hold == s_aready_hold[1])) begin
            s_bvalid <= 1'b1;
            s_bdata <= m_bdata_hold;
            s_active <= 1'b0;
        end

        s_aready_hold <= { s_aready_hold[0], m_aready_hold };
    end
end

always @(posedge m_clk or negedge rst_n) begin
    if (!rst_n) begin
        m_avalid_hold <= 2'b00;
        m_aready_hold <= 1'b0;
        m_avalid <= 1'b0;
        m_active <= 1'b0;
        m_awe <= 1'b0;
        m_aaddr <= 1'b0;
        m_adata <= 1'b0;
        m_astrb <= 1'b0;
    end else begin
        if (m_aready)
            m_avalid <= 1'b0;

        if (!m_active && (m_avalid_hold[1] != m_aready_hold)) begin
            m_active <= 1'b1;
            m_avalid <= 1'b1;
            m_awe <= awe;
            m_aaddr <= aaddr;
            m_adata <= adata;
            m_astrb <= astrb;
        end

        if (m_bvalid) begin
            m_bdata_hold <= m_bdata;
            m_aready_hold <= m_avalid_hold[1];
            m_active <= 1'b0;
        end

        m_avalid_hold <= { m_avalid_hold[0], s_avalid_hold };
    end
end

endmodule

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
