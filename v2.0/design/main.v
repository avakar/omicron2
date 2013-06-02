module main(
    input clk_in,
    output reg[2:0] led,
    inout[16:1] s,
    output[16:1] sd,

    output reg flash_cs,
    output reg flash_si,
    output reg flash_clk,
    input flash_so
    );
    
reg[24:0] counter;
wire blink_strobe = (counter == 1'b0);
always @(posedge clk_in) begin
    if (counter == 1'b0)
        counter <= 25'd33333333;
    else
        counter <= counter - 1'b1;
end

always @(posedge clk_in) begin
    if (blink_strobe)
        led <= { led[1], led[0], !led[2] };
end

wire jtag1_sel, jtag1_reset, jtag1_tdi, jtag1_capture, jtag1_update, jtag1_shift, jtag_tck;

BSCAN_SPARTAN6 #(
    .JTAG_CHAIN(1)
)
jtag1(
    .SEL(jtag1_sel),
    .RESET(jtag1_reset),
    .TDI(jtag1_tdi),
    .DRCK(),
    .CAPTURE(jtag1_capture),
    .UPDATE(jtag1_update),
    .SHIFT(jtag1_shift),
    .RUNTEST(),
    .TCK(jtag_tck),
    .TMS(),
    .TDO(flash_so)
    );

always @(posedge jtag_tck or posedge jtag1_reset) begin
    if (jtag1_reset) begin
        flash_cs <= 1'b1;
        flash_clk <= 1'b1;
    end else if (jtag1_sel) begin
        flash_clk <= 1'b1;
        if (jtag1_capture) begin
            flash_cs <= 1'b0;
        end else if (jtag1_update) begin
            flash_cs <= 1'b1;
        end else if (jtag1_shift) begin
            if (flash_clk)
                flash_si <= jtag1_tdi;
            flash_clk <= !flash_clk;
        end
    end
end

assign s = 16'sbz;
assign sd = 16'sb0;

endmodule
