module sample_mux_one #(
    parameter w = 16
    )(
    input[w-1:0] i,
    output o,
    input[$clog2(w)-1:0] s
    );

assign o = i[s];

endmodule

module sample_mux #(
    parameter w = 16
    )(
    input[w-1:0] i,
    output[w-1:0] o,
    input[$clog2(w)*w-1:0] s
    );

genvar x;
generate
    for (x = 0; x < w; x = x + 1) begin : g
        sample_mux_one #(.w(w)) z(
            .i(i),
            .o(o[x]),
            .s(s[$clog2(w)*(x+1)-1:$clog2(w)*x])
            );
    end
endgenerate

endmodule

// Note that for the compressor to work, each cycle where in_strobe
// is set should be immediately followed by a cycle in which
// in_strobe is clear.
//
// The size of the output stream can be up to 1.5 times that
// of the input stream, but will typically be much closer to 0.
module sample_compressor(
    input clk,
    input rst_n,

    input[15:0] in_data,
    input in_strobe,
    output reg[15:0] out_data,
    output reg out_strobe,

    output reg overflow_error
    );

localparam
    st_init    = 2'd0,
    st_single  = 2'd1,
    st_run     = 2'd2,
    st_recover = 2'd3;

reg[1:0] state;
reg[15:0] last_data;
reg[15:0] cntr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= st_init;
        last_data <= 16'sbx;
        out_data <= 1'sbx;
        out_strobe <= 1'b0;
        overflow_error <= 1'b0;
    end else begin
        out_data <= 1'sbx;
        out_strobe <= 1'b0;
        case (state)
            st_init: if (in_strobe) begin
                state <= st_single;
                out_data <= in_data;
                out_strobe <= 1'b1;
            end
            st_single: if (in_strobe) begin
                out_data <= in_data;
                out_strobe <= 1'b1;
                if (last_data == in_data) begin
                    state <= st_run;
                    cntr <= 1'b0;
                end
            end
            st_run: if (in_strobe) begin
                if (last_data != in_data) begin
                    state <= st_recover;
                    out_data <= cntr;
                    out_strobe <= 1'b1;
                end else begin
                    if (cntr == 16'hFFFE) begin
                        out_data <= 16'hFFFF;
                        out_strobe <= 1'b1;
                    end
                end
                if (cntr == 16'hFFFE)
                    cntr <= 1'b0;
                else
                    cntr <= cntr + 1'b1;
            end
            st_recover: begin
                if (in_strobe)
                    overflow_error <= 1'b1;
                state <= st_single;
                out_data <= last_data;
                out_strobe <= 1'b1;
            end
        endcase
        
        if (in_strobe)
            last_data <= in_data;
    end
end

endmodule

module sample_strober(
    input clk,
    input rst_n,

    input[15:0] s,
    output sample_strobe,

    input[3:0] waddr,
    input[31:0] wdata,
    input wvalid
    );

reg enable;
reg[31:0] period;
reg[31:0] cntr;
wire cntr_strobe = (cntr == period);

reg[15:0] rising_edge_mask;
reg[15:0] falling_edge_mask;
reg[15:0] last_s;

wire[15:0] rising_edges = ~last_s & s & rising_edge_mask;
wire[15:0] falling_edges = last_s & ~s & falling_edge_mask;
wire edge_strobe = (rising_edges != 0) || (falling_edges != 0);

assign sample_strobe = (enable && cntr_strobe) || edge_strobe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cntr <= 1'b0;
        period <= 1'b0;
        enable <= 1'b0;
        rising_edge_mask <= 1'b0;
        falling_edge_mask <= 1'b0;
    end else begin
        last_s <= s;

        if (enable) begin
            if (cntr_strobe)
                cntr <= 1'b0;
            else
                cntr <= cntr + 1'b1;
        end

        if (wvalid) begin
            case (waddr)
                4'h0: begin
                    enable <= wdata[0];
                    if (wdata[1])
                        cntr <= 1'b0;
                end
                4'h4: begin
                    period <= wdata;
                end
                4'h8: begin
                    rising_edge_mask <= wdata[15:0];
                    falling_edge_mask <= wdata[31:16];
                end
            endcase
        end
    end
end

endmodule

// The sampler input `s` must already be synchronized
// to avoid metastability.
module sampler(
    input clk,
    input rst_n,

    input[15:0] s,

    output[15:0] out_data,
    output out_valid,

    output compressor_overflow_error,

    input[4:0] waddr,
    input[31:0] wdata,
    input wvalid
    );

wire[15:0] s_muxed;
reg[63:0] in_mux;
sample_mux #(.w(16)) mux0(
    .i(s),
    .o(s_muxed),
    .s(in_mux)
    );

wire sample_strobe;
sample_strober strober0(
    .clk(clk),
    .rst_n(rst_n),

    .s(s_muxed),
    .sample_strobe(sample_strobe),

    .waddr(waddr[3:0]),
    .wdata(wdata),
    .wvalid(wvalid && (waddr[4] == 0))
    );

sample_compressor compressor0(
    .clk(clk),
    .rst_n(rst_n),

    .in_data(s_muxed),
    .in_strobe(sample_strobe),
    .out_data(out_data),
    .out_strobe(out_valid),

    .overflow_error(compressor_overflow_error)
    );

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_mux <= 64'hFEDCBA9876543210;
    end else begin
        if (wvalid) begin
            case (waddr)
                5'h10: begin
                    in_mux[31:0] <= wdata;
                end
                5'h14: begin
                    in_mux[63:32] <= wdata;
                end
            endcase
        end
    end
end

endmodule
