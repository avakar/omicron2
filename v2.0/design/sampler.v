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
//
// The compressor will auto-restart every 32Ki samples (a page),
// in order to inject restart points for the potential parser.
// The autoreset counter should be reset using the `clear` signal
// before starting a sampling run. The `new_page` signal will be
// asserted along with the first sample in each page.
//
// The compressor also keeps a 40-bit sample index and pushes
// it out along with the `out_data`.
module sample_compressor(
    input clk,
    input rst_n,

    input clear,

    input[15:0] in_data,
    input in_strobe,

    output reg new_page,
    output reg[15:0] out_data,
    output reg out_strobe,
    output reg[39:0] out_sample_index,

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
reg[14:0] reset_cntr;

reg[39:0] sample_index;

wire end_page = (reset_cntr == 15'h7fff);
reg new_page_latch;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= st_init;
        last_data <= 16'sbx;
        out_data <= 1'sbx;
        out_strobe = 1'b0;
        overflow_error <= 1'b0;
        reset_cntr <= 1'b0;
        new_page_latch <= 1'b1;
        new_page <= 1'b0;
        sample_index <= 1'b0;
    end else begin
        out_data <= 1'sbx;
        out_sample_index <= 1'sbx;
        out_strobe = 1'b0;

        if (clear) begin
            state <= st_init;
            overflow_error <= 1'b0;
            reset_cntr <= 1'b0;
            new_page_latch <= 1'b1;
            new_page <= 1'b0;
            sample_index <= 1'b0;
        end else begin
            case (state)
                st_init: if (in_strobe) begin
                    out_data <= in_data;
                    out_strobe = 1'b1;
                    out_sample_index <= sample_index;
                    if (!end_page)
                        state <= st_single;
                end
                st_single: if (in_strobe) begin
                    out_data <= in_data;
                    out_strobe = 1'b1;
                    out_sample_index <= sample_index;
                    if (end_page) begin
                        state <= st_init;
                    end else if (last_data == in_data) begin
                        state <= st_run;
                        cntr <= 1'b0;
                    end
                end
                st_run: if (in_strobe) begin
                    if (cntr == 1'b0)
                        out_sample_index <= sample_index;

                    if (last_data != in_data) begin
                        state <= st_recover;
                        out_data <= cntr;
                        out_strobe = 1'b1;
                    end else begin
                        if (cntr == 16'hFFFE) begin
                            out_data <= 16'hFFFF;
                            out_strobe = 1'b1;
                            if (end_page)
                                state <= st_init;
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
                    out_strobe = 1'b1;
                    out_sample_index <= sample_index;
                end
            endcase

            if (out_strobe) begin
                reset_cntr <= reset_cntr + 1'b1;
                new_page_latch <= end_page;
                new_page <= new_page_latch;
            end
        end

        if (in_strobe) begin
            last_data <= in_data;
            sample_index <= sample_index + 1'b1;
        end
    end
end

endmodule

module sample_strober(
    input clk,
    input rst_n,

    input[15:0] s,
    output reg sample_strobe,

    input enable,
    input clear_timer,

    input[31:0] period,
    input[15:0] rising_edge_mask,
    input[15:0] falling_edge_mask
    );

reg[31:0] cntr;
reg cntr_strobe;

reg[15:0] last_s;

wire[15:0] rising_edges = ~last_s & s & rising_edge_mask;
wire[15:0] falling_edges = last_s & ~s & falling_edge_mask;
wire edge_strobe = (rising_edges != 0) || (falling_edges != 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cntr <= 1'b0;
    end else begin
        cntr_strobe <= (cntr == period);
        sample_strobe <= (enable && cntr_strobe) || edge_strobe;
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

    output[63:0] index_data,
    output index_valid,

    output compressor_overflow_error,

    input avalid,
    input awe,
    input[4:0] aaddr,
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

reg[15:0] s_mux_latch;
always @(posedge clk) begin
    s_mux_latch <= s_muxed;
end

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

    .s(s_mux_latch),
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

wire compr_new_page;
wire[39:0] compr_sample_index;
sample_compressor compressor0(
    .clk(clk),
    .rst_n(rst_n && !clear_pipeline),

    .clear(clear_pipeline),

    .in_data(ser_data),
    .in_strobe(ser_strobe),
    .out_data(out_data),
    .out_strobe(out_valid),

    .new_page(compr_new_page),
    .out_sample_index(compr_sample_index),

    .overflow_error(compressor_overflow_error)
    );

assign index_data = compr_sample_index;

assign index_valid = out_valid && compr_new_page;

reg[31:0] temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_mux <= 64'hFEDCBA9876543210;
        enable_timer <= 1'b0;
        clear_timer <= 1'b0;
        log_channels <= 3'd4;
        clear_pipeline <= 1'b0;
        bvalid <= 1'b0;
        period <= 1'b0;
        rising_edge_mask <= 1'b0;
        falling_edge_mask <= 1'b0;
        temp <= 1'bx;
    end else begin
        clear_timer <= 1'b0;
        clear_pipeline <= 1'b0;
        bvalid <= 1'b0;
        bdata <= 1'sbx;

        if (avalid && awe) begin
            case (aaddr)
                5'h0: begin
                    enable_timer <= adata[0];
                    if (adata[1])
                        clear_timer <= 1'b1;
                    if (adata[2])
                        clear_pipeline <= 1'b1;
                    log_channels <= adata[6:4];
                end
                5'h4: begin
                    period <= adata;
                end
                5'h8: begin
                    falling_edge_mask <= adata[15:0];
                    rising_edge_mask <= adata[31:16];
                end
                5'h10: begin
                    in_mux[31:0] <= adata;
                end
                5'h14: begin
                    in_mux[63:32] <= adata;
                end
            endcase
        end

        if (avalid && !awe) begin
            case (aaddr)
                5'h0: bdata <= { 1'b0, log_channels, 3'b0, enable_timer };
                5'h4: bdata <= period;
                5'h8: bdata <= { rising_edge_mask, falling_edge_mask };
                5'hC: bdata <= { ser_data, sample_index[15:0] };
                5'h10: bdata <= in_mux[31:0];
                5'h14: bdata <= in_mux[63:32];
                5'h18: begin
                    bdata <= sample_index[31:0];
                    temp <= sample_index[63:32];
                end
                5'h1C: bdata <= temp;
                default: bdata <= 1'sbx;
            endcase
        end

        bvalid <= avalid;
    end
end

endmodule
