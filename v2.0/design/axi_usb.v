module axi_usb(
    input rst_n,
    input clk_48,

    input avalid,
    output aready,
    input awe,
    input[15:2] aaddr,
    input[31:0] adata,
    output reg bvalid,
    output reg[31:0] bdata,

    input rx_j,
    input rx_se0,
    output tx_en,
    output tx_j,
    output tx_se0,
    output pup_en,

    output mem_we,
    output[9:0] mem_addr,
    output[7:0] mem_write_data,
    input[7:0] mem_read_data
    );

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;

wire usb_transaction_active;
wire[3:0] usb_endpoint;
wire usb_direction_in;
wire usb_setup;
reg[1:0] usb_handshake;
wire[7:0] usb_data_out;
wire usb_data_strobe;
wire usb_success;
reg usb_data_toggle;
reg usb_in_data_valid;
reg usb_bank;
reg[6:0] usb_addr_ptr;
reg[6:0] usb_address;
wire usb_reset;

usb usb0(
    .rst_n(rst_n),
    .clk_48(clk_48),

    .rx_j(rx_j),
    .rx_se0(rx_se0),

    .tx_en(tx_en),
    .tx_j(tx_j),
    .tx_se0(tx_se0),

    .usb_address(usb_address),

    .usb_rst(usb_reset),

    .transaction_active(usb_transaction_active),
    .endpoint(usb_endpoint),
    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .data_toggle(usb_data_toggle),

    .handshake(usb_handshake),

    .data_out(usb_data_out),
    .data_in(mem_read_data),
    .data_in_valid(usb_in_data_valid),
    .data_strobe(usb_data_strobe),
    .success(usb_success)
    );

reg usb_reset_prev, usb_reset_flag;
reg usb_attach;
assign pup_en = usb_attach;

wire usb_ep0_toggle;
wire[1:0] usb_ep0_handshake;
wire usb_ep0_bank;
wire usb_ep0_in_data_valid;
wire[15:0] usb_ep0_ctrl_rd_data;
usb_ep usb_ep0(
    .clk(clk_48),

    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .success(usb_endpoint == 4'b0 && usb_success),
    .cnt(usb_addr_ptr),

    .toggle(usb_ep0_toggle),
    .handshake(usb_ep0_handshake),
    .bank(usb_ep0_bank),
    .in_data_valid(usb_ep0_in_data_valid),

    .ctrl_dir_in(aaddr[2]),
    .ctrl_rd_data(usb_ep0_ctrl_rd_data),
    .ctrl_wr_data(adata[15:0]),
    .ctrl_wr_strobe(avalid && awe && {aaddr[15:4],4'b0} == 16'h0100)
    );

wire usb_ep1_toggle;
wire[1:0] usb_ep1_handshake;
wire usb_ep1_bank;
wire usb_ep1_in_data_valid;
wire[15:0] usb_ep1_ctrl_rd_data;
usb_ep usb_ep1(
    .clk(clk_48),

    .direction_in(usb_direction_in),
    .setup(usb_setup),
    .success(usb_endpoint == 4'b1 && usb_success),
    .cnt(usb_addr_ptr),

    .toggle(usb_ep1_toggle),
    .handshake(usb_ep1_handshake),
    .bank(usb_ep1_bank),
    .in_data_valid(usb_ep1_in_data_valid),

    .ctrl_dir_in(aaddr[2]),
    .ctrl_rd_data(usb_ep1_ctrl_rd_data),
    .ctrl_wr_data(adata[15:0]),
    .ctrl_wr_strobe(avalid && awe && {aaddr[15:4],4'b0} == 16'h0110)
    );

always @(*) begin
    case (usb_endpoint)
        4'd0: begin
            usb_data_toggle = usb_ep0_toggle;
            usb_in_data_valid = usb_ep0_in_data_valid;
            usb_bank = usb_ep0_bank;
            usb_handshake = usb_ep0_handshake;
        end
        4'd1: begin
            usb_data_toggle = usb_ep1_toggle;
            usb_in_data_valid = usb_ep1_in_data_valid;
            usb_bank = usb_ep1_bank;
            usb_handshake = usb_ep1_handshake;
        end
        default: begin
            usb_data_toggle = 1'bx;
            usb_in_data_valid = 1'bx;
            usb_bank = 1'bx;
            usb_handshake = hs_stall;
        end
    endcase
end

assign mem_we = usb_data_strobe && !usb_addr_ptr[6] && !usb_direction_in;
assign mem_addr = {usb_endpoint[1:0], usb_direction_in, usb_bank, usb_addr_ptr[5:0]};
assign mem_write_data = usb_data_out;

always @(*) begin
    casez ({ aaddr, 2'b00 })
        16'h0000:
            bdata = { usb_addr_ptr, 6'b0, usb_reset_flag, usb_attach };
        16'h0004:
            bdata = usb_address;
        16'h010?:
            bdata = usb_ep0_ctrl_rd_data;
        16'h011?:
            bdata = usb_ep1_ctrl_rd_data;
        default:
            bdata = 32'sbx;
    endcase
end

always @(posedge clk_48 or negedge rst_n) begin
    if (!rst_n) begin
        bvalid <= 1'b0;
        usb_attach <= 1'b0;
        usb_address <= 6'b0;
        usb_reset_flag <= 1'b0;
        usb_reset_prev <= 1'b0;
        usb_addr_ptr <= 1'b0;
    end else begin
        usb_reset_prev <= usb_reset;
        if (usb_reset && !usb_reset_prev)
            usb_reset_flag <= 1'b1;

        if (!usb_transaction_active) begin
            usb_addr_ptr <= 1'b0;
        end else if (usb_data_strobe) begin
            if (!usb_addr_ptr[6])
                usb_addr_ptr <= usb_addr_ptr + 1'b1;
        end

        bvalid <= avalid && !aready;
        if (avalid && awe) begin
            casez ({ aaddr, 2'b00 })
                16'h0000: begin
                    usb_attach <= adata[0];
                    if (adata[2])
                        usb_reset_flag <= 1'b0;
                end
                16'h0004: begin
                    usb_address <= adata[6:0];
                end
            endcase
        end
    end
end

assign aready = bvalid;

endmodule
