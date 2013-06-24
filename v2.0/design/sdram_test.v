`timescale 1ns / 1ns

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   12:37:06 06/15/2013
// Design Name:   sdram
// Module Name:   C:/devel/checkouts/omicron_analyzer2/v2.0/design/sdram_test.v
// Project Name:  design_v20
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: sdram
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sdram_test;

	// Inputs
	reg rst_n;
	reg clk;
	reg [23:0] awaddr;
	reg awvalid;
	reg [15:0] wdata;
	reg wvalid;
	reg [23:0] araddr;
	reg arvalid;

	// Outputs
	wire wready;
	wire arready;
	wire [15:0] rdata;
	wire rvalid;
	wire m_cs;
	wire m_ras;
	wire m_cas;
	wire m_we;
	wire [1:0] m_ba;
	wire [12:0] m_a;
	wire [1:0] m_dqm;

	// Bidirs
	wire [15:0] m_dq;

	// Instantiate the Unit Under Test (UUT)
    defparam uut.init_count = 15'd50;
    defparam uut.t_ref1     = 100;
	sdram uut (
		.rst(!rst_n), 
		.clk(clk), 
		.awaddr(awaddr), 
		.wdata(wdata), 
		.wready(wready), 
		.wvalid(wvalid), 
		.araddr(araddr), 
		.arready(arready), 
		.arvalid(arvalid), 
		.rdata(rdata), 
		.rvalid(rvalid), 
		.m_cs(m_cs), 
		.m_ras(m_ras), 
		.m_cas(m_cas), 
		.m_we(m_we), 
		.m_ba(m_ba), 
		.m_a(m_a), 
		.m_dqm(m_dqm), 
		.m_dq(m_dq)
	);

    sdram_model sdram0(
        .clk(clk),
        .cke_n(1'b0),
        .cs_n(m_cs),
        .ras_n(m_ras),
        .cas_n(m_cas),
        .we_n(m_we),
        .ba(m_ba),
        .a(m_a),
        .dq(m_dq),
        .dqm(m_dqm)
        );

    always #5 clk = !clk;
    
    task write(input[23:0] addr, input[15:0] data);
    begin
        awaddr <= addr;
        wdata <= data;
        wvalid <= 1;
        @(posedge clk) while (!wready) @(posedge clk);
        wvalid <= 0;
    end
    endtask

    task begin_read(input[23:0] addr);
    begin
        araddr <= addr;
        arvalid <= 1;
        @(posedge clk) while (!arready) @(posedge clk);
        arvalid <= 0;
    end
    endtask

	initial begin
		// Initialize Inputs
		rst_n = 0;
		clk = 0;
		awaddr = 0;
		awvalid = 0;
		wdata = 0;
		wvalid = 0;
		araddr = 0;
		arvalid = 0;

		// Wait 100 ns for global reset to finish
		#100;
        rst_n = 1;
        
		// Add stimulus here
        @(posedge clk);
        
        write(1, 16'd0);
        write(2, 16'd1);
        write(3, 16'd2);
        write(512, 16'd3);
        write(513, 16'd4);

        begin_read(2);
        begin_read(3);

        write(3, 42);

        begin_read(3);
        
        write(4, 43);
        write(5, 44);
        write(1029, 45);
        write(4101, 46);
        write(8197, 47);
        write(8198, 48);
        write(8199, 49);
        write(8200, 50);
	end
      
endmodule

