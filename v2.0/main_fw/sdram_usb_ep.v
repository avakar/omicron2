module sdram_usb_ep(
    input rst_n,
    input clk,

    input transaction_active,
    input direction_in,
    input success,
    input[6:0] cnt,

    output toggle,
    output reg[1:0] handshake,
    output in_data_valid,
    output[7:0] in_data,
    input[7:0] out_data,
    input data_strobe,

    input ctrl_dir_in,
    output reg[15:0] ctrl_rd_data,
    input[7:0] ctrl_wr_data,
    input[0:0] ctrl_wr_en,

    input mem_clk,
    input[4:0] wr_addr,
    input[15:0] wr_data,
    input wr_en,
    input wr_push,
    output wr_full,

    output[15:0] rd_data,
    input rd_pull,
    output rd_empty
    );

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;

reg rd_force_pull;
wire rd_fifo_empty;
sdram_to_usb rd_fifo(
    .rst_n(rst_n),

    .wr_clk(mem_clk),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .wr_push(wr_push),
    .wr_full(wr_full),

    .rd_clk(clk),
    .rd_addr(cnt[5:0]),
    .rd_data(in_data),
    .rd_pull((success && direction_in) || rd_force_pull),
    .rd_empty(rd_fifo_empty)
    );

wire wr_fifo_full;
usb_to_sdram wr_fifo(
    .rst_n(rst_n),

    .wr_clk(clk),
    .wr_addr(cnt),
    .wr_data(out_data),
    .wr_en(data_strobe && !direction_in),
    .wr_push(success && !direction_in),
    .wr_full(wr_fifo_full),

    .rd_clk(mem_clk),
    .rd_data(rd_data),
    .rd_pull(rd_pull),
    .rd_empty(rd_empty)
    );

assign in_data_valid = !rd_fifo_empty && !cnt[6];

reg ep_in_toggle;
reg ep_in_stall;
reg ep_in_pause;
reg ep_out_toggle;
reg ep_out_stall;
reg ep_out_pause;

always @(*) begin
    if (direction_in) begin
        if (ep_in_stall)
            handshake = hs_stall;
        else if (rd_fifo_empty || ep_in_pause)
            handshake = hs_nak;
        else
            handshake = hs_ack;
    end else begin
        if (ep_out_stall)
            handshake = hs_stall;
        else if (wr_fifo_full || ep_out_pause)
            handshake = hs_nak;
        else
            handshake = hs_ack;
    end
end

assign toggle = direction_in? ep_in_toggle: ep_out_toggle;

wire in_transit = direction_in && transaction_active && handshake == hs_ack;
wire out_transit = !direction_in && transaction_active && handshake == hs_ack;

always @(*) begin
    if (ctrl_dir_in) begin
        ctrl_rd_data[15:8] = 7'd64;
        ctrl_rd_data[7:0] = { ep_in_pause, in_transit, 1'b0, ep_in_toggle, ep_in_stall, 1'b0, rd_fifo_empty, !rd_fifo_empty };
    end else begin
        ctrl_rd_data[15:8] = 0;
        ctrl_rd_data[7:0] = { ep_out_pause, out_transit, 1'b0, ep_out_toggle, ep_out_stall, 1'b0, !wr_fifo_full, wr_fifo_full };
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ep_in_stall <= 1'b0;
        ep_in_toggle <= 1'b0;
        ep_in_pause <= 1'b0;
        ep_out_stall <= 1'b0;
        ep_out_toggle <= 1'b0;
        ep_out_pause <= 1'b0;
        rd_force_pull <= 1'b0;
    end else begin
        rd_force_pull <= 1'b0;

        if (success) begin
            if (direction_in) begin
                ep_in_toggle <= !ep_in_toggle;
            end else begin
                ep_out_toggle <= !ep_out_toggle;
            end
        end

        if (ctrl_wr_en[0] && ctrl_dir_in) begin
            if (ctrl_wr_data[7])
                ep_in_pause <= 1'b0;
            if (ctrl_wr_data[6])
                ep_in_pause <= 1'b1;

            if (ctrl_wr_data[5]) begin
                ep_in_toggle <= 1'b0;
                ep_in_stall <= 1'b0;
            end
            if (ctrl_wr_data[4]) begin
                ep_in_toggle <= 1'b1;
                ep_in_stall <= 1'b0;
            end
            if (ctrl_wr_data[3])
                ep_in_stall <= 1'b1;

            rd_force_pull <= ctrl_wr_data[1];
        end

        if (ctrl_wr_en[0] && !ctrl_dir_in) begin
            if (ctrl_wr_data[7])
                ep_out_pause <= 1'b0;
            if (ctrl_wr_data[6])
                ep_out_pause <= 1'b1;

            if (ctrl_wr_data[5]) begin
                ep_out_toggle <= 1'b0;
                ep_out_stall <= 1'b0;
            end
            if (ctrl_wr_data[4]) begin
                ep_out_toggle <= 1'b1;
                ep_out_stall <= 1'b0;
            end
            if (ctrl_wr_data[3])
                ep_out_stall <= 1'b1;
        end
    end
end

endmodule

module sdram_to_usb(
    input rst_n,

    input wr_clk,
    input[4:0] wr_addr,
    input[15:0] wr_data,
    input wr_en,
    input wr_push,
    output wr_full,

    input rd_clk,
    input[5:0] rd_addr,
    output[7:0] rd_data,
    input rd_pull,
    output rd_empty
    );

reg[3:0] wr_ptr, wr_ptr_send, wr_ptr_recv;
reg[3:0] rd_ptr, rd_ptr_send, rd_ptr_recv;

reg[2:0] wr_sync;
reg[2:0] rd_sync;

wire[3:0] wr_ptr_next = wr_ptr + 1'b1;

assign rd_empty = rd_ptr == wr_ptr_recv;
assign wr_full = wr_ptr_next == rd_ptr_recv;

xclock_mem mem0(
  .clka(wr_clk),
  .wea(wr_en),
  .addra({ wr_ptr, wr_addr }),
  .dina(wr_data),

  .clkb(rd_clk),
  .addrb({ rd_ptr, rd_addr }),
  .doutb(rd_data)
);

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_sync[0] <= 1'b0;
        rd_sync[2:1] <= 2'b00;
        wr_ptr <= 1'b0;
        wr_ptr_send <= 1'b0;
        rd_ptr_recv <= 1'b0;
    end else begin
        rd_sync[2:1] <= rd_sync[1:0];
        wr_sync[0] <= rd_sync[2];
        if (wr_sync[0] != rd_sync[2]) begin
            wr_ptr_send <= wr_ptr;
            rd_ptr_recv <= rd_ptr_send;
        end

        if (wr_push) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
end

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_sync[0] <= 1'b0;
        wr_sync[2:1] <= 2'b00;
        rd_ptr <= 1'b0;
        rd_ptr_send <= 1'b0;
        wr_ptr_recv <= 1'b0;
    end else begin
        wr_sync[2:1] <= wr_sync[1:0];
        rd_sync[0] <= !wr_sync[2];
        if (rd_sync[0] == wr_sync[2]) begin
            rd_ptr_send <= rd_ptr;
            wr_ptr_recv <= wr_ptr_send;
        end

        if (rd_pull) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
end

endmodule

module usb_to_sdram(
    input rst_n,

    input wr_clk,
    input[6:0] wr_addr,
    input[7:0] wr_data,
    input wr_en,
    input wr_push,
    output wr_full,

    input rd_clk,
    output reg[15:0] rd_data,
    input rd_pull,
    output reg rd_empty
    );

reg[9:0] wr_ptr;
reg[8:0] rd_ptr;
reg[8:0] wr_ptr_send;
reg[8:0] rd_ptr_send;
reg[8:0] wr_ptr_recv;
reg[8:0] rd_ptr_recv;
reg[2:0] wr_sync;
reg[2:0] rd_sync;

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_sync[0] <= 1'b0;
        rd_sync[2:1] <= 2'b00;
        wr_ptr_send <= 1'b0;
        rd_ptr_recv <= 1'b0;
    end else begin
        rd_sync[2:1] <= rd_sync[1:0];
        wr_sync[0] <= !rd_sync[2];
        if (wr_sync[0] == rd_sync[2]) begin
            wr_ptr_send <= wr_ptr[9:1];
            rd_ptr_recv <= rd_ptr_send;
        end
    end
end

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_sync[0] <= 1'b0;
        wr_sync[2:1] <= 2'b00;
        rd_ptr_send <= 1'b0;
        wr_ptr_recv <= 1'b0;
    end else begin
        wr_sync[2:1] <= wr_sync[1:0];
        rd_sync[0] <= wr_sync[2];
        if (rd_sync[0] != wr_sync[2]) begin
            rd_ptr_send <= rd_ptr;
            wr_ptr_recv <= wr_ptr_send;
        end
    end
end

wire[8:0] rd_ptr_next = rd_ptr + 1'b1;
wire[15:0] rd_data_pre;

wire rd_empty_pre = wr_ptr_recv == rd_ptr;
wire rd_pull_pre = !rd_empty_pre && (rd_empty || rd_pull);

xclock_mem_8_to_16 mem0(
    .clka(wr_clk),
    .wea(wr_en),
    .addra(wr_ptr + wr_addr),
    .dina(wr_data),

    .clkb(rd_clk),
    .addrb(rd_pull_pre? rd_ptr_next: rd_ptr),
    .doutb(rd_data_pre)
);

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 1'b0;
    end else begin
        if (wr_push)
            wr_ptr <= wr_ptr + wr_addr;
    end
end

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_empty <= 1'b1;
        rd_ptr <= 1'b0;
    end else begin
        if (rd_pull_pre) begin
            rd_empty <= 1'b0;
            rd_data <= rd_data_pre;
            rd_ptr <= rd_ptr + 1'b1;
        end else if (rd_pull) begin
            rd_empty <= 1'b1;
        end
    end
end

wire[9:0] wr_capacity = { rd_ptr_recv, 1'b0 } - wr_ptr - 1'b1;
assign wr_full = wr_capacity < 9'd64;

endmodule
