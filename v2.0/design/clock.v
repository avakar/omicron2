module clock_controller(
    input rst,
    input clk_33,
    output clk_48
    );

wire pll_fb;
wire clk_100;
PLL_BASE #(
    .CLKIN_PERIOD(30),
    .COMPENSATION("PLL2DCM"),
    .CLKFBOUT_MULT(18),
    .CLKOUT0_DIVIDE(6),
    .CLK_FEEDBACK("CLKFBOUT")
    )
    pll_200(
    .CLKIN(clk_33),
    .CLKFBIN(pll_fb),
    .RST(rst),
    .CLKOUT0(clk_100),
    .CLKOUT1(),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKFBOUT(pll_fb),
    .LOCKED()
    );

wire dcm_clk0;
DCM_SP #(
    .CLKIN_PERIOD(10),
    .CLK_FEEDBACK("1X"),
    .CLKFX_MULTIPLY(12),
    .CLKFX_DIVIDE(25)
    )
    dcm_48 (
    .CLKIN(clk_100),
    .CLKFB(dcm_clk0),
    .RST(rst),
    .PSEN(1'b0),
    .CLK0(dcm_clk0),
    .CLKFX(clk_48),
    .CLKFX180(),
    .LOCKED(),
    .CLKDV(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLK2X(),
    .CLK2X180(),
    .PSDONE(),
    .STATUS(),
    .DSSEN(),
    .PSCLK(),
    .PSINCDEC()
    );

endmodule
