module clock_controller(
    input rst,
    input clk_33,
    output clk_48,
    output clk_sampler,
    output clk_dram,
    output clk_dram_out,
    output clk_dram_out_n,
    output locked
    );

wire pll_fb;
wire clk_100, clk_100_g;
wire clk_sampler_g;
wire pll_locked;
PLL_BASE #(
    .CLKIN_PERIOD(30),
    .COMPENSATION("PLL2DCM"),
    .CLKFBOUT_MULT(18),
    .CLKOUT0_DIVIDE(6),
    .CLKOUT1_DIVIDE(3),
    .CLKOUT2_DIVIDE(6),
    .CLK_FEEDBACK("CLKFBOUT")
    )
    pll_200(
    .CLKIN(clk_33),
    .CLKFBIN(pll_fb),
    .RST(rst),
    .CLKOUT0(clk_100_g),
    .CLKOUT1(clk_sampler_g),
    .CLKOUT2(clk_dram_g),
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

BUFG clk_sampler_bufg(
    .I(clk_sampler_g),
    .O(clk_sampler)
    );

BUFG clk_dram_bufg(
    .I(clk_dram_g),
    .O(clk_dram)
    );

wire dcm_48_clkfx;
wire dcm_48_locked0;
wire dcm_48_fb;
DCM_SP #(
    .CLK_FEEDBACK("1X"),
    .CLKFX_MULTIPLY(12),
    .CLKFX_DIVIDE(25)
    )
    dcm_48 (
    .CLKIN(clk_100),
    .CLKFB(dcm_48_fb),
    .RST(rst || !pll_locked),
    .PSEN(1'b0),
    .CLK0(dcm_48_fb),
    .CLKFX(clk_48_g),
    .CLKFX180(),
    .LOCKED(dcm_48_locked0),
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

reg dcm_48_locked1;
reg dcm_48_locked;
always @(posedge clk_48 or negedge dcm_48_locked0) begin
    if (!dcm_48_locked0) begin
        dcm_48_locked1 <= 1'b0;
        dcm_48_locked <= 1'b0;
    end else begin
        dcm_48_locked1 <= 1'b1;
        dcm_48_locked <= dcm_48_locked1;
    end
end

wire dcm_dram_out_clk0, dcm_dram_out_clk180;
wire clk_dram_out_g, clk_dram_out_n_g;
DCM_SP #(
    .CLK_FEEDBACK("1X"),
    .CLKOUT_PHASE_SHIFT("FIXED"),
    .PHASE_SHIFT(-49)
    )
    dcm_dram (
    .CLKIN(clk_100),
    .CLKFB(clk_dram_out),
    .RST(rst || !pll_locked || !dcm_48_locked),
    .PSEN(1'b0),
    .CLK0(clk_dram_out_g),
    .CLKFX(),
    .CLKFX180(),
    .LOCKED(locked),
    .CLKDV(),
    .CLK90(),
    .CLK180(clk_dram_out_n_g),
    .CLK270(),
    .CLK2X(),
    .CLK2X180(),
    .PSDONE(),
    .STATUS(),
    .DSSEN(1'b0),
    .PSCLK(1'b0),
    .PSINCDEC(1'b0)
    );

BUFG clk_dram_out_bufg(
    .I(clk_dram_out_g),
    .O(clk_dram_out)
    );

BUFG clk_dram_out_n_bufg(
    .I(clk_dram_out_n_g),
    .O(clk_dram_out_n)
    );

endmodule
