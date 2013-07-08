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

    input enable,
    input clear_timer,

    input[31:0] period,
    input[15:0] rising_edge_mask,
    input[15:0] falling_edge_mask
    );

reg[31:0] cntr;
wire cntr_strobe = (cntr == period);

reg[15:0] last_s;

wire[15:0] rising_edges = ~last_s & s & rising_edge_mask;
wire[15:0] falling_edges = last_s & ~s & falling_edge_mask;
wire edge_strobe = (rising_edges != 0) || (falling_edges != 0);

assign sample_strobe = (enable && cntr_strobe) || edge_strobe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cntr <= 1'b0;
    end else begin
        last_s <= s;

        if (enable) begin
            if (cntr_strobe)
                cntr <= 1'b0;
            else
                cntr <= cntr + 1'b1;
        end

        if (clear_timer)
            cntr <= 1'b0;
    end
end

endmodule

module sample_serializer(
    input clk,
    input rst_n,

    input[15:0] in_data,
    input in_strobe,
    output reg[15:0] out_data,
    output reg out_strobe,
    output reg[63:0] sample_index,

    input[2:0] log_channels
    );

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_strobe <= 1'b0;
        sample_index <= 1'b0;
    end else begin
        if (out_strobe)
            out_strobe <= 1'b0;

        if (in_strobe) begin
            case (log_channels)
                3'd0: begin
                    out_data <= { out_data[14:0], in_data[0] };
                    if (sample_index[3:0] == 4'd15)
                        out_strobe <= 1'b1;
                    sample_index <= sample_index + 4'd1;
                end
                3'd1: begin
                    out_data <= { out_data[13:0], in_data[1:0] };
                    if (sample_index[3:0] == 4'd14)
                        out_strobe <= 1'b1;
                    sample_index <= sample_index + 4'd2;
                end
                3'd2: begin
                    out_data <= { out_data[11:0], in_data[3:0] };
                    if (sample_index[3:0] == 4'd12)
                        out_strobe <= 1'b1;
                    sample_index <= sample_index + 4'd4;
                end
                3'd3: begin
                    out_data <= { out_data[7:0], in_data[7:0] };
                    if (sample_index[3:0] == 4'd8)
                        out_strobe <= 1'b1;
                    sample_index <= sample_index + 4'd8;
                end
                default: begin
                    out_data <= in_data;
                    out_strobe <= 1'b1;
                    sample_index <= sample_index + 5'd16;
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

    input avalid,
    input awe,
    input[4:2] aaddr,
    input[31:0] adata,
    output reg bvalid,
    output reg[31:0] bdata
    );

wire[15:0] s_muxed;
reg[63:0] in_mux;
sample_mux #(.w(16)) mux0(
    .i(s),
    .o(s_muxed),
    .s(in_mux)
    );

reg enable_timer;
reg clear_timer;

reg[31:0] period;
reg[15:0] rising_edge_mask;
reg[15:0] falling_edge_mask;

reg clear_pipeline;

wire sample_strobe;
sample_strober strober0(
    .clk(clk),
    .rst_n(rst_n && !clear_pipeline),

    .enable(enable_timer),
    .clear_timer(clear_timer),

    .s(s_muxed),
    .sample_strobe(sample_strobe),

    .period(period),
    .rising_edge_mask(rising_edge_mask),
    .falling_edge_mask(falling_edge_mask)
    );

reg[2:0] log_channels;

wire ser_strobe;
wire[15:0] ser_data;
wire[63:0] sample_index;

sample_serializer ser0(
    .clk(clk),
    .rst_n(rst_n && !clear_pipeline),

    .in_data(s_muxed),
    .in_strobe(sample_strobe),
    .out_data(ser_data),
    .out_strobe(ser_strobe),
    .sample_index(sample_index),

    .log_channels(log_channels)
    );

sample_compressor compressor0(
    .clk(clk),
    .rst_n(rst_n && !clear_pipeline),

    .in_data(ser_data),
    .in_strobe(ser_strobe),
    .out_data(out_data),
    .out_strobe(out_valid),

    .overflow_error(compressor_overflow_error)
    );

reg[31:0] temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_mux <= 64'hFEDCBA9876543210;
        enable_timer <= 1'b0;
        clear_timer <= 1'b0;
        log_channels <= 3'd4;
        clear_pipeline <= 1'b0;
        period <= 1'b0;
        rising_edge_mask <= 1'b0;
        falling_edge_mask <= 1'b0;
        temp <= 1'bx;

        bvalid <= 1'b0;
    end else begin
        clear_timer <= 1'b0;
        clear_pipeline <= 1'b0;

        bvalid <= 1'b0;
        bdata <= 1'sbx;

        if (avalid && awe) begin
            case (aaddr)
                3'h0: begin
                    enable_timer <= adata[0];
                    if (adata[1])
                        clear_timer <= 1'b1;
                    if (adata[2])
                        clear_pipeline <= 1'b1;
                    log_channels <= adata[6:4];
                end
                3'h1: begin
                    period <= adata;
                end
                3'h2: begin
                    falling_edge_mask <= adata[15:0];
                    rising_edge_mask <= adata[31:16];
                end
                3'h4: begin
                    in_mux[31:0] <= adata;
                end
                3'h5: begin
                    in_mux[63:32] <= adata;
                end
            endcase
        end

        if (avalid && !awe) begin
            case (aaddr)
                3'h0: bdata <= { 1'b0, log_channels, 3'b0, enable_timer };
                3'h1: bdata <= period;
                3'h2: bdata <= { rising_edge_mask, falling_edge_mask };
                3'h3: bdata <= { ser_data, sample_index[15:0] };
                3'h4: bdata <= in_mux[31:0];
                3'h5: bdata <= in_mux[63:32];
                3'h6: begin
                    bdata <= sample_index[31:0];
                    temp <= sample_index[63:32];
                end
                3'h7: bdata <= temp;
            endcase
        end

        bvalid <= avalid;
    end
end

endmodule
