module spiviajtag(
    output reg clk,
    output reg cs_n,
    input miso,
    output reg mosi
    );

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
    .TDO(miso)
    );

always @(posedge jtag_tck or posedge jtag1_reset) begin
    if (jtag1_reset) begin
        cs_n <= 1'b1;
        clk <= 1'b1;
        mosi <= 1'bx;
    end else if (jtag1_sel) begin
        if (jtag1_update) begin
            cs_n <= 1'b1;
        end else if (jtag1_capture) begin
            cs_n <= 1'b0;
        end

        if (jtag1_shift) begin
            if (clk)
                mosi <= jtag1_tdi;
            else
                mosi <= mosi;
            clk <= !clk;
        end else begin
            clk <= 1'b1;
            mosi <= 1'bx;
        end
    end
end

endmodule
