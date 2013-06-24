module sdram_wr_fifo(
    input rst,
    input clk,

    input[23:0] awaddr,
    input[15:0] wdata,
    input wvalid,
    output wready,

    output[23:0] f_addr,
    output[15:0] f_data,
    output f_valid,
    input f_ack
    );

reg[23:0] l_addr;
reg[15:0] l_data;
reg l_full;

assign wready = !l_full || f_ack;
assign f_addr = wready? awaddr: l_addr;
assign f_data = wready? wdata: l_data;
assign f_valid = wvalid || !wready;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        l_addr <= 1'sbx;
        l_data <= 1'sbx;
        l_full <= 1'b0;
    end else begin
        if (wvalid && wready) begin
            l_addr <= awaddr;
            l_data <= wdata;
            l_full <= 1'b1;
        end
        
        if (!wvalid && f_ack)
            l_full <= 1'b0;
    end
end

endmodule

module sdram_rd_fifo(
    input rst,
    input clk,

    input[23:0] araddr,
    input arvalid,
    output arready,

    output[23:0] f_addr,
    output f_valid,
    input f_ack
    );

reg[23:0] l_addr;
reg l_full;

assign arready = !l_full || f_ack;
assign f_addr = arready? araddr: l_addr;
assign f_valid = arvalid || !arready;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        l_addr <= 1'sbx;
        l_full <= 1'b0;
    end else begin
        if (arvalid && arready) begin
            l_addr <= araddr;
            l_full <= 1'b1;
        end
        
        if (!arvalid && f_ack)
            l_full <= 1'b0;
    end
end

endmodule

module sdram(
    input rst,
    input clk,

    input[23:0] awaddr,
    input[15:0] wdata,
    input wvalid,
    output wready,

    input[23:0] araddr,
    output arready,
    input arvalid,
    (* IOB = "FORCE" *) output reg[15:0] rdata,
    output reg rvalid,

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

// @48MHz
parameter init_count = 15000;
parameter t_init_oe  = 11000;
parameter t_init_clk = 10500;
parameter t_init_cke = 10000;
parameter t_rfc      = 7;
parameter t_rp       = 3;
parameter t_mrd      = 2;
parameter t_rcd      = 3;
parameter t_cas      = 2;
parameter t_ref1     = 374;
parameter t_ras_min  = 5;
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

genvar gi;
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : dq_obuf_gen
        IOBUF dq_obuf(
            .T(m_dq_oe_n[gi]),
            .I(m_dq_out[gi]),
            .O(m_dq_in[gi]),
            .IO(m_dq[gi])
            );
//        assign m_dq[gi] = !m_dq_oe_n[gi]? m_dq_out[gi]: 1'bz;
    end
endgenerate

reg[12:0] active_rowaddr;
(* KEEP = "TRUE" *) reg[1:0] active_bank;
reg[2:0] read_queue;

wire[23:0] wf_addr;
wire[15:0] wf_data;
wire wf_valid;
(* KEEP = "TRUE" *) reg wf_ack;
sdram_wr_fifo wr_fifo(
    .rst(rst),
    .clk(clk),

    .awaddr(awaddr),
    .wdata(wdata),
    .wvalid(wvalid),
    .wready(wready),

    .f_addr(wf_addr),
    .f_data(wf_data),
    .f_valid(wf_valid),
    .f_ack(wf_ack)
    );

wire[23:0] rf_addr;
wire rf_valid;
reg rf_ack;
sdram_rd_fifo rd_fifo(
    .rst(rst),
    .clk(clk),

    .araddr(araddr),
    .arvalid(arvalid),
    .arready(arready),

    .f_addr(rf_addr),
    .f_valid(rf_valid),
    .f_ack(rf_ack)
    );

wire[8:0] wf_coladdr = wf_addr[8:0];
wire[1:0] wf_ba = wf_addr[10:9];
wire[12:0] wf_rowaddr = wf_addr[23:11];

wire[8:0] rf_coladdr = rf_addr[8:0];
wire[1:0] rf_ba = rf_addr[10:9];
wire[12:0] rf_rowaddr = rf_addr[23:11];

reg[$clog2(t_ref1)-1:0] refresh_cnt;
reg refresh_now;

reg[$clog2(t_ras_min)-1:0] precharge_guard;

reg[$clog2(t_rfc)-1:0] delay_cnt;
reg cmd_enable;
reg m_cke0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cmd <= 1'b0;
        cmd_enable <= 1'b0;
        m_clk_oe <= 1'b0;
        m_cke <= 1'b0;
        m_cke0 <= 1'b0;
        m_a <= 1'b0;
        m_ba <= 2'b00;
        active_bank <= 2'b00;
        m_dq_oe_n <= 16'hFFFF;
        m_dq_out <= 1'sbx;
        state <= st_init;
        delay_cnt <= 1'b0;
        active_rowaddr <= 1'sbx;
        init_counter <= init_count;
        read_queue <= 3'b000;
        refresh_cnt <= t_ref1-1;
        refresh_now <= 1'b0;
        precharge_guard <= 1'b0;

        rvalid <= 1'b0;
        
        wf_ack <= 1'b0;
        rf_ack <= 1'b0;
    end else begin
        m_a <= 1'b0;
        cmd <= cmd_enable? cmd_nop: 1'b0;
        m_dq_out <= 1'sbx;
        m_dq_oe_n <= 16'hFFFF;
        rvalid <= 1'b0;
        rdata <= 1'sbx;
        wf_ack <= 1'b0;
        rf_ack <= 1'b0;
        m_cke <= m_cke0;
        
        rdata <= m_dq_in;
        if (read_queue[2])
            rvalid <= 1'b1;
        read_queue <= { read_queue[1:0], 1'b0 };

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
                    end else if (rf_valid) begin
                        m_ba <= rf_ba;
                        active_bank <= rf_ba;
                        m_a <= rf_rowaddr;
                        cmd <= cmd_active;
                        active_rowaddr <= rf_rowaddr;
                        state <= st_active;
                        delay_cnt <= t_rcd - 1'b1;
                        precharge_guard <= t_ras_min-1;
                    end else if (wf_valid) begin
                        m_ba <= wf_ba;
                        active_bank <= wf_ba;
                        m_a <= wf_rowaddr;
                        cmd <= cmd_active;
                        active_rowaddr <= wf_rowaddr;
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
                    end else if (wf_valid && !read_queue) begin
                        m_a[10] <= 1'b0;
                        if (wf_ba != active_bank || active_rowaddr != wf_rowaddr) begin
                            if (!precharge_guard) begin
                                cmd <= cmd_precharge;
                                state <= st_idle;
                                if (wf_ba == active_bank)
                                    delay_cnt <= t_rfc - 1'b1;
                            end
                        end else begin
                            m_a[8:0] <= wf_coladdr;
                            m_dq_out <= wf_data;
                            m_dq_oe_n <= 16'h0000;
                            cmd <= cmd_write;
                            wf_ack <= 1'b1;
                        end
                    end else if (rf_valid) begin
                        m_a[10] <= 1'b0;
                        if (rf_ba != active_bank || active_rowaddr != rf_rowaddr) begin
                            if (!precharge_guard) begin
                                cmd <= cmd_precharge;
                                state <= st_idle;
                                if (rf_ba == active_bank)
                                    delay_cnt <= t_rfc - 1'b1;
                            end
                        end else begin
                            m_a[8:0] <= rf_coladdr;
                            cmd <= cmd_read;
                            rf_ack <= 1'b1;
                            read_queue[0] <= 1'b1;
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
