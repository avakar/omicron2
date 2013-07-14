module aaxi_async_bridge_test;

	// Inputs
	reg rst_n;
	reg s_clk;
	reg s_avalid;
	reg s_awe;
	reg [31:2] s_aaddr;
	reg [31:0] s_adata;
	reg [3:0] s_astrb;
	wire m_clk;
	reg m_aready;
	reg m_bvalid;
	reg [31:0] m_bdata;

	// Outputs
	wire s_bvalid;
	wire [31:0] s_bdata;
	wire m_avalid;
	wire m_awe;
	wire [31:2] m_aaddr;
	wire [31:0] m_adata;
	wire [3:0] m_astrb;

	// Instantiate the Unit Under Test (UUT)
	aaxi_async_bridge uut (
		.rst_n(rst_n), 
		.s_clk(s_clk), 
		.s_avalid(s_avalid), 
		.s_awe(s_awe), 
		.s_aaddr(s_aaddr), 
		.s_adata(s_adata), 
		.s_astrb(s_astrb), 
		.s_bvalid(s_bvalid), 
		.s_bdata(s_bdata), 
		.m_clk(m_clk), 
		.m_avalid(m_avalid), 
		.m_aready(m_aready), 
		.m_awe(m_awe), 
		.m_aaddr(m_aaddr), 
		.m_adata(m_adata), 
		.m_astrb(m_astrb), 
		.m_bvalid(m_bvalid), 
		.m_bdata(m_bdata)
	);

    always #5 s_clk = !s_clk;
    assign m_clk = s_clk;

	initial begin
		// Initialize Inputs
		rst_n = 0;
		s_clk = 0;
		s_avalid = 0;
		s_awe = 0;
		s_aaddr = 0;
		s_adata = 0;
		s_astrb = 0;
		m_aready = 1;
		m_bvalid = 0;
		m_bdata = 0;

		// Wait 100 ns for global reset to finish
		#100;
        rst_n = 1;
		#100;
        @(posedge s_clk);

		// Add stimulus here
        s_awe = 1;
        s_aaddr = 0;
        s_adata = 42;
        s_astrb = 4'b1111;
        s_avalid = 1;
        @(posedge s_clk);
        
        s_avalid = 0;

        while (!m_avalid) @(posedge m_clk);
        m_bdata = 55;
        m_bvalid = 1;
        @(posedge m_clk);
        m_bvalid = 0;

        //////
        while (!s_bvalid) @(posedge m_clk);
        s_awe = 1;
        s_aaddr = 0;
        s_adata = 43;
        s_astrb = 4'b1111;
        s_avalid = 1;
        @(posedge m_clk);
        
        s_avalid = 0;
	end
      
endmodule

