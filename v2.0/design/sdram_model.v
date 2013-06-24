`timescale 1ns / 1ns

`define assert(condition) begin if(!(condition)) begin $display("Assertion failed!"); $finish(1); end; end

module sdram_bank(
    input clk,
    input cs,
    input ras_n,
    input cas_n,
    input we_n,
    input[12:0] a,
    inout[15:0] dq,
    input[1:0] dqm
    );

parameter t_rc = 66;
parameter t_ras_min = 44;
parameter t_rcd = 20;
parameter t_rp = 20;

reg[15:0] m[8191:0][2047:0];

reg[15:0] dqr_delayed;
reg[15:0] dqr;
assign dq = dqr_delayed;

reg active;
reg[12:0] row_address;

reg[15:0] dqr_queue;

time last_active_cmd_time;
time last_precharge_time;

initial begin
    dqr_delayed = 1'sbz;
    dqr = 1'sbz;
    dqr_queue = 1'sbz;
    last_active_cmd_time = $time;
    last_precharge_time = $time;
end

always @(dqr) begin
    if (dqr_delayed[0] == 1'sbz) begin
        #1 dqr_delayed = 1'sbx;
        #5 dqr_delayed = dqr;
    end else begin
        #2 dqr_delayed = 1'sbx;
        #4 dqr_delayed = dqr;
    end
end

always @(posedge clk) begin
    dqr_queue <= 1'sbz;
    dqr <= dqr_queue;

    if (cs) begin
        if ({ras_n, cas_n, we_n} != 3'b111) begin
            `assert(last_precharge_time + t_rp < $time);
        end

        case ({ras_n, cas_n, we_n})
            3'b011: begin // active
                `assert(!active);
                `assert(last_active_cmd_time + t_rc < $time);
                last_active_cmd_time = $time;
                row_address <= a;
                active <= 1;
            end
            3'b101: begin // read
                `assert(active);
                `assert(last_active_cmd_time + t_rcd < $time);
                dqr_queue <= m[row_address][a[8:0]];
            end
            3'b100: begin // write
                `assert(active);
                `assert(last_active_cmd_time + t_rcd < $time);
                m[row_address][a[8:0]] <= dq;
            end
            3'b010: begin // precharge
                `assert(last_active_cmd_time + t_ras_min < $time);
                last_precharge_time = $time;
                active <= 0;
            end
            3'b001: begin // refresh
                `assert(!active);
            end
        endcase
    end
end

endmodule

module sdram_model(
    input clk,
    input cke_n,
    input cs_n,
    input ras_n,
    input cas_n,
    input we_n,
    input[1:0] ba,
    input[12:0] a,
    inout[15:0] dq,
    input[1:0] dqm
    );

parameter t_rrd = 15;
parameter t_rp = 20;
parameter t_rfc = 66;

reg[14:0] mode;
wire all_precharge = (a[10] == 1 && {ras_n,cas_n,we_n} == 3'b010);

sdram_bank b0(
    .clk(clk),
    .cs(!cke_n && !cs_n && (ba == 2'd0 || all_precharge)),
    .ras_n(ras_n),
    .cas_n(cas_n),
    .we_n(we_n),
    .a(a),
    .dq(dq),
    .dqm(dqm)
    );

sdram_bank b1(
    .clk(clk),
    .cs(!cke_n && !cs_n && (ba == 2'd1 || all_precharge)),
    .ras_n(ras_n),
    .cas_n(cas_n),
    .we_n(we_n),
    .a(a),
    .dq(dq),
    .dqm(dqm)
    );

sdram_bank b2(
    .clk(clk),
    .cs(!cke_n && !cs_n && (ba == 2'd2 || all_precharge)),
    .ras_n(ras_n),
    .cas_n(cas_n),
    .we_n(we_n),
    .a(a),
    .dq(dq),
    .dqm(dqm)
    );

sdram_bank b3(
    .clk(clk),
    .cs(!cke_n && !cs_n && (ba == 2'd3 || all_precharge)),
    .ras_n(ras_n),
    .cas_n(cas_n),
    .we_n(we_n),
    .a(a),
    .dq(dq),
    .dqm(dqm)
    );

time last_row0_refresh_time;
time last_refresh_time;
reg[12:0] refresh_counter;

time last_active_cmd_time;

initial begin
    last_row0_refresh_time = $time;
    last_refresh_time = $time;
    last_active_cmd_time = $time;
    refresh_counter = 0;
end

always @(posedge clk) begin
    `assert($time - last_row0_refresh_time < 64000000);

    if (!cke_n && !cs_n) begin
        if ({ras_n, cas_n, we_n} != 3'b111) begin
            `assert(last_refresh_time + t_rfc < $time);
        end

        case ({ras_n, cas_n, we_n})
            3'b000: begin
                `assert({ba, a} == 15'b000000000100000);
            end
            3'b001: begin // refresh
                last_refresh_time = $time;
                if (refresh_counter == 0)
                    last_row0_refresh_time = $time;
                refresh_counter = refresh_counter + 1;
            end
            3'b011: begin // active
                `assert(last_active_cmd_time + t_rrd < $time);
                last_active_cmd_time = $time;
            end
            
        endcase
    end
end

endmodule
