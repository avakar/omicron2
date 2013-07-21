module sdram_fifo(
    input rst,
    input clk,

    input awe,
    input[23:0] aaddr,
    input[15:0] adata,
    input avalid,
    output aready,

    output f_we,
    output[23:0] f_addr,
    output[15:0] f_data,
    output f_valid,
    input f_ack
    );

reg l_we;
reg[23:0] l_addr;
reg[15:0] l_data;
reg l_full;

assign aready = !l_full || f_ack;
assign f_we = aready? awe: l_we;
assign f_addr = aready? aaddr: l_addr;
assign f_data = aready? adata: l_data;
assign f_valid = avalid || !aready;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        l_we <= 1'bx;
        l_addr <= 1'sbx;
        l_data <= 1'sbx;
        l_full <= 1'b0;
    end else begin
        if (avalid && aready) begin
            l_we <= awe;
            l_addr <= aaddr;
            l_data <= adata;
            l_full <= 1'b1;
        end
        
        if (!avalid && f_ack)
            l_full <= 1'b0;
    end
end

endmodule

module sdram(
    input rst,
    input clk,

    input avalid,
    output aready,
    input awe,
    input[23:0] aaddr,
    input[15:0] adata,
    output reg bvalid,
    output reg bwe,
    output reg[15:0] bdata,

    output reg m_clk_oe,
    output reg m_cke,
    output m_ras,
    output m_cas,
    output m_we,
    output reg[1:0] m_ba,
    output reg[12:0] m_a,
    output[1:0] m_dqm,
    inout[15:0] m_dq
    );

assign m_dqm = 2'b00;

// @100MHz
// We're going for a 250us initialization cycle.
// Since we'll likely be starting the power regulator
// for the SDRAM from the design, we need about 150us
// just for the regulator to start an stabilize.
// In the meantime, all outputs will be set low
// and clocks stopped (also low).
//
// After 150us, we'll raise ras_n, cas_n and we_n thus
// pushing the noop command to the sdram. Still,
// the clocks are disabled and cke is low.
//
// A little bit after that we'll enable clock. Then,
// we'll raise cke. At this point, the SDRAM is receiving
// the noop command.
//
// At the very end of the initialization timeout,
// we'll push precharge, two auto-refresh cycles and
// then load the mode register.
//
// Then the SDRAM is initialized.
parameter init_count = 25000;
parameter t_init_oe  = 15000;
parameter t_init_clk = 14000;
parameter t_init_cke = 13000;
parameter t_rfc      = 7;   // 66ns
parameter t_rp       = 2;   // 20ns
parameter t_mrd      = 2;   // 2ck
parameter t_rcd      = 2;   // 20ns
parameter t_ref1     = 781; // 7812.5ns
parameter t_ras_min  = 5;   // 44ns
parameter mode_reg   = 13'b0000000100000;

localparam
    cmd_nop       = 3'b111,
    cmd_active    = 3'b011,
    cmd_read      = 3'b101,
    cmd_write     = 3'b100,
    cmd_term      = 3'b110,
    cmd_precharge = 3'b010,
    cmd_refresh   = 3'b001,
    cmd_lmr       = 3'b000;

localparam
    st_init   = 2'd0,
    st_idle   = 2'd1,
    st_active = 2'd2;

reg[1:0] state;

reg[$clog2(init_count) - 1:0] init_counter;
reg[2:0] cmd;
assign { m_ras, m_cas, m_we } = cmd;

(* KEEP = "TRUE" *) (* IOB = "FORCE" *) reg[15:0] m_dq_out;
(* KEEP = "TRUE" *) (* IOB = "FORCE" *) reg[15:0] m_dq_oe_n;
wire[15:0] m_dq_in;

reg m_cke0;

genvar gi;
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : dq_obuf_gen
        IOBUF dq_obuf(
            .T(m_dq_oe_n[gi]),
            .I(m_dq_out[gi]),
            .O(m_dq_in[gi]),
            .IO(m_dq[gi])
            );
    end
endgenerate

reg[12:0] active_rowaddr;
(* KEEP = "TRUE" *) reg[1:0] active_bank;
reg[2:0] read_queue;

wire f_we;
wire[23:0] f_addr;
wire[15:0] f_data;
wire f_valid;
(* KEEP = "TRUE" *) reg f_ack;
sdram_fifo fifo(
    .rst(rst),
    .clk(clk),

    .awe(awe),
    .aaddr(aaddr),
    .adata(adata),
    .avalid(avalid),
    .aready(aready),

    .f_we(f_we),
    .f_addr(f_addr),
    .f_data(f_data),
    .f_valid(f_valid),
    .f_ack(f_ack)
    );

wire[8:0] f_coladdr = f_addr[8:0];
wire[1:0] f_ba = f_addr[10:9];
wire[12:0] f_rowaddr = f_addr[23:11];

reg[$clog2(t_ref1)-1:0] refresh_cnt;
reg refresh_now;

reg[$clog2(t_ras_min)-1:0] precharge_guard;

reg[$clog2(t_rfc)-1:0] delay_cnt;
reg cmd_enable;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cmd <= 1'b0;
        cmd_enable <= 1'b0;

        state <= st_init;

        m_clk_oe <= 1'b0;
        m_cke <= 1'b0;
        m_cke0 <= 1'b0;
        m_a <= 1'b0;
        m_ba <= 2'b00;
        m_dq_oe_n <= 16'hFFFF;
        m_dq_out <= 1'sbx;

        active_bank <= 2'b00;
        delay_cnt <= 1'b0;
        active_rowaddr <= 1'sbx;
        init_counter <= init_count;
        read_queue <= 3'b000;
        refresh_cnt <= t_ref1-1;
        refresh_now <= 1'b0;
        precharge_guard <= 1'b0;

        bvalid <= 1'b0;
        bdata <= 1'sbx;
        bwe <= 1'bx;
        f_ack <= 1'b0;
    end else begin
        m_a <= 1'b0;
        cmd <= cmd_enable? cmd_nop: 1'b0;
        m_dq_out <= 1'sbx;
        m_dq_oe_n <= 16'hFFFF;
        f_ack <= 1'b0;
        bwe <= 1'bx;
        
        bdata <= m_dq_in;
        bvalid <= read_queue[2];
        if (read_queue[2])
            bwe <= 1'b0;
        read_queue <= { read_queue[1:0], 1'b0 };

        m_cke <= m_cke0;

        if (refresh_cnt) begin
            refresh_cnt <= refresh_cnt - 1'b1;
        end else begin
            refresh_cnt <= t_ref1-1;
            refresh_now <= 1'b1;
        end

        if (precharge_guard)
            precharge_guard <= precharge_guard - 1'b1;

        if (!delay_cnt) begin
            case (state)
                st_init: begin
                    init_counter <= init_counter - 1'b1;
                    case (init_counter)
                        t_init_oe: begin
                            cmd_enable <= 1'b1;
                        end
                        t_init_clk: begin
                            m_clk_oe <= 1'b1;
                        end
                        t_init_cke: begin
                            m_cke0 <= 1'b1;
                        end
                        t_mrd + 2*t_rfc + t_rp: begin
                            cmd <= cmd_precharge;
                            m_a[10] <= 1'b1;
                        end
                        t_mrd + 2*t_rfc: begin
                            cmd <= cmd_refresh;
                        end
                        t_mrd + 1*t_rfc: begin
                            cmd <= cmd_refresh;
                        end
                        t_mrd: begin
                            cmd <= cmd_lmr;
                            m_a <= mode_reg;
                        end
                        0: begin
                            state <= st_idle;
                        end
                    endcase
                end
                st_idle: begin
                    active_bank <= 1'sbx;
                    if (refresh_now) begin
                        cmd <= cmd_refresh;
                        delay_cnt <= t_rfc-1;
                        refresh_now <= 1'b0;
                    end else if (f_valid) begin
                        m_ba <= f_ba;
                        active_bank <= f_ba;
                        m_a <= f_rowaddr;
                        cmd <= cmd_active;
                        active_rowaddr <= f_rowaddr;
                        state <= st_active;
                        delay_cnt <= t_rcd - 1'b1;
                        precharge_guard <= t_ras_min-1;
                    end
                end
                st_active: begin
                    if (refresh_now && !precharge_guard) begin
                        cmd <= cmd_precharge;
                        state <= st_idle;
                        delay_cnt <= t_rfc - 1'b1;
                    end else if (f_valid && (!f_we || !read_queue)) begin
                        m_a[10] <= 1'b0;
                        if (f_ba != active_bank || active_rowaddr != f_rowaddr) begin
                            if (!precharge_guard) begin
                                cmd <= cmd_precharge;
                                state <= st_idle;
                                if (f_ba == active_bank)
                                    delay_cnt <= t_rfc - 1'b1;
                            end
                        end else begin
                            m_a[8:0] <= f_coladdr;
                            m_dq_out <= f_data;
                            if (f_we) begin
                                m_dq_oe_n <= 16'h0000;
                                cmd <= cmd_write;
                                bvalid <= 1'b1;
                                bwe <= 1'b1;
                            end else begin
                                read_queue[0] <= 1'b1;
                                cmd <= cmd_read;
                            end
                            f_ack <= 1'b1;
                        end
                    end
                end
            endcase
        end else begin
            delay_cnt <= delay_cnt - 1'b1;
        end
    end
end

endmodule
