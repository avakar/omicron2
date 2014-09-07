module clock_controller(
    input rst_n,
    input clk_33,
    output clk_48,
    output locked
    );

wire pll_fb;
wire clk_100, clk_100_g;
wire pll_locked;
PLL_BASE #(
    .CLKIN_PERIOD(30),
    .COMPENSATION("PLL2DCM"),
    .CLKFBOUT_MULT(18),
    .CLKOUT0_DIVIDE(6),
    .CLK_FEEDBACK("CLKFBOUT")
    )
    pll_100(
    .CLKIN(clk_33),
    .CLKFBIN(pll_fb),
    .RST(!rst_n),
    .CLKOUT0(clk_100_g),
    .CLKOUT1(),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKFBOUT(pll_fb),
    .LOCKED(pll_locked)
    );

BUFG clk_100_bufg(
    .I(clk_100_g),
    .O(clk_100)
    );

wire dcm_48_fb;
wire dcm_48_locked;
DCM_SP #(
    .CLK_FEEDBACK("1X"),
    .CLKFX_MULTIPLY(12),
    .CLKFX_DIVIDE(25)
    )
    dcm_48 (
    .CLKIN(clk_100),
    .CLKFB(dcm_48_fb),
    .RST(!rst_n || !pll_locked),
    .PSEN(1'b0),
    .CLK0(dcm_48_fb),
    .CLKFX(clk_48_g),
    .CLKFX180(),
    .LOCKED(dcm_48_locked),
    .CLKDV(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLK2X(),
    .CLK2X180(),
    .PSDONE(),
    .STATUS(),
    .DSSEN(1'b0),
    .PSCLK(1'b0),
    .PSINCDEC(1'b0)
    );

BUFG clk_48_bufg(
    .I(clk_48_g),
    .O(clk_48)
    );

assign locked = dcm_48_locked;

endmodule
