`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   13:09:55 06/23/2013
// Design Name:   main
// Module Name:   C:/devel/checkouts/omicron_analyzer2/v2.0/design/main_test.v
// Project Name:  design_v20
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: main
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module main_test;

	// Inputs
	reg rst_n;
	reg clk_33;
	reg flash_so;
	reg usb_sp;
	reg usb_sn;

	// Outputs
	wire [2:0] led;
	wire [15:0] sd;
	wire vio_33;
	wire vio_50;
	wire flash_cs;
	wire flash_si;
	wire flash_clk;
	wire m_pwren;
	wire m_clk;
	wire m_cs_n;
	wire m_cke;
	wire [12:0] m_a;
	wire [1:0] m_ba;
	wire m_ras_n;
	wire m_cas_n;
	wire m_we_n;
	wire m_ldqm;
	wire m_udqm;

	// Bidirs
	wire [15:0] s;
	wire usb_pup;
	wire usb_dp;
	wire usb_dn;
	wire [15:0] m_dq;

	// Instantiate the Unit Under Test (UUT)
	main uut (
		.rst_n(rst_n), 
		.clk_33(clk_33), 
		.led(led), 
		.s(s), 
		.sd(sd), 
		.vio_33(vio_33), 
		.vio_50(vio_50), 
		.flash_cs(flash_cs), 
		.flash_si(flash_si), 
		.flash_clk(flash_clk), 
		.flash_so(flash_so), 
		.usb_pup(usb_pup), 
		.usb_sp(usb_sp), 
		.usb_sn(usb_sn), 
		.usb_dp(usb_dp), 
		.usb_dn(usb_dn), 
		.m_pwren(m_pwren), 
		.m_clk(m_clk), 
		.m_cs_n(m_cs_n), 
		.m_cke(m_cke), 
		.m_a(m_a), 
		.m_ba(m_ba), 
		.m_ras_n(m_ras_n), 
		.m_cas_n(m_cas_n), 
		.m_we_n(m_we_n), 
		.m_ldqm(m_ldqm), 
		.m_udqm(m_udqm), 
		.m_dq(m_dq)
	);

    always #15 clk_33 = !clk_33;

	initial begin
		// Initialize Inputs
		rst_n = 0;
		clk_33 = 0;
		flash_so = 0;
		usb_sp = 0;
		usb_sn = 0;

		// Wait 100 ns for global reset to finish
		#100;
        rst_n = 1;
        
		// Add stimulus here

	end
      
endmodule

