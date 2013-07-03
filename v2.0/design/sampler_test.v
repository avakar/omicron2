`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   23:41:36 07/03/2013
// Design Name:   sampler
// Module Name:   C:/devel/checkouts/omicron_analyzer2/v2.0/design/sampler_test.v
// Project Name:  design_v20
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: sampler
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sampler_test;

	// Inputs
	reg clk;
	reg rst_n;
	reg [15:0] s;
	reg [4:0] waddr;
	reg [31:0] wdata;
	reg wvalid;

	// Outputs
	wire [15:0] out_data;
	wire out_valid;
	wire compressor_overflow_error;

	// Instantiate the Unit Under Test (UUT)
	sampler uut (
		.clk(clk), 
		.rst_n(rst_n), 
		.s(s), 
		.out_data(out_data), 
		.out_valid(out_valid), 
		.compressor_overflow_error(compressor_overflow_error), 
		.waddr(waddr), 
		.wdata(wdata), 
		.wvalid(wvalid)
	);

    always #5 clk = !clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst_n = 0;
		s = 0;
		waddr = 0;
		wdata = 0;
		wvalid = 0;

		// Wait 100 ns for global reset to finish
		#100;
        rst_n = 1;
        
		// Add stimulus here
        @(posedge clk);
        waddr = 4;
        wdata = 2;
        wvalid = 1;

        @(posedge clk);
        waddr = 0;
        wdata = { 3'd3, 1'b0, 1'b1 };

        @(posedge clk);
        wvalid = 0;
	end
      
endmodule

