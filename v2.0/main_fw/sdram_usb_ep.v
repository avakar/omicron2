module sdram_usb_ep(
    input rst_n,
    input clk,

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
    .rd_pull(success && direction_in),
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
reg ep_out_toggle;
reg ep_out_stall;

always @(*) begin
    if (direction_in) begin
        if (ep_in_stall)
            handshake = hs_stall;
        else if (rd_fifo_empty)
            handshake = hs_nak;
        else
            handshake = hs_ack;
    end else begin
        if (ep_out_stall)
            handshake = hs_stall;
        else if (wr_fifo_full)
            handshake = hs_nak;
        else
            handshake = hs_ack;
    end
end

assign toggle = direction_in? ep_in_toggle: ep_out_toggle;

always @(*) begin
    if (ctrl_dir_in) begin
        ctrl_rd_data[15:8] = 7'd64;
        ctrl_rd_data[7:0] = { ep_in_toggle, ep_in_stall, 1'b0, rd_fifo_empty, !rd_fifo_empty };
    end else begin
        ctrl_rd_data[15:8] = 0;
        ctrl_rd_data[7:0] = { ep_out_toggle, ep_out_stall, 1'b0, !wr_fifo_full, wr_fifo_full };
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ep_in_stall <= 1'b0;
        ep_in_toggle <= 1'b0;
    end else begin
        if (success) begin
            if (direction_in) begin
                ep_in_toggle <= !ep_in_toggle;
            end else begin
                ep_out_toggle <= !ep_out_toggle;
            end
        end

        if (ctrl_wr_en[0] && ctrl_dir_in) begin
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
        end

        if (ctrl_wr_en[0] && !ctrl_dir_in) begin
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

reg[3:0] wr_ptr, wr_gray0, wr_gray1, wr_gray2;
reg[3:0] rd_ptr, rd_gray0, rd_gray1, rd_gray2;

reg[3:0] wr_gray0_next;
always @(*) begin
    case (wr_gray0)
        4'b0000: wr_gray0_next = 4'b0001;
        4'b0001: wr_gray0_next = 4'b0011;
        4'b0011: wr_gray0_next = 4'b0010;
        4'b0010: wr_gray0_next = 4'b0110;
        4'b0110: wr_gray0_next = 4'b0111;
        4'b0111: wr_gray0_next = 4'b0101;
        4'b0101: wr_gray0_next = 4'b0100;
        4'b0100: wr_gray0_next = 4'b1100;
        4'b1100: wr_gray0_next = 4'b1101;
        4'b1101: wr_gray0_next = 4'b1111;
        4'b1111: wr_gray0_next = 4'b1110;
        4'b1110: wr_gray0_next = 4'b1010;
        4'b1010: wr_gray0_next = 4'b1011;
        4'b1011: wr_gray0_next = 4'b1001;
        4'b1001: wr_gray0_next = 4'b1000;
        4'b1000: wr_gray0_next = 4'b0000;
    endcase
end

assign rd_empty = rd_gray0 == wr_gray2;
assign wr_full = wr_gray0_next == rd_gray2;

xclock_mem mem0(
  .clka(wr_clk),
  .wea(wr_en),
  .addra({ wr_ptr, wr_addr }),
  .dina(wr_data),

  .clkb(rd_clk),
  .addrb({ rd_ptr, rd_addr }),
  .doutb(rd_data)
);

wire[3:0] rd_next = (rd_ptr + 1'b1);
wire[3:0] wr_next = (wr_ptr + 1'b1);

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 1'b0;
        wr_gray0 <= 1'b0;
        rd_gray1 <= 1'b0;
        rd_gray2 <= 1'b0;
    end else begin
        rd_gray1 <= rd_gray0;
        rd_gray2 <= rd_gray1;
        if (wr_push) begin
            wr_ptr <= wr_next;
            wr_gray0 <= wr_next ^ (wr_next >> 1);
        end
    end
end

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= 1'b0;
        rd_gray0 <= 1'b0;
        wr_gray1 <= 1'b0;
        wr_gray2 <= 1'b0;
    end else begin
        wr_gray1 <= wr_gray0;
        wr_gray2 <= wr_gray1;
        if (rd_pull) begin
            rd_ptr <= rd_next;
            rd_gray0 <= rd_next ^ (rd_next >> 1);
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
