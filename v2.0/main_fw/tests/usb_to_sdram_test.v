`timescale 1ns / 1ns
module usb_to_sdram_test;

// Inputs
reg rst_n;
reg wr_clk;
reg [6:0] wr_addr;
reg [7:0] wr_data;
reg wr_en;
reg wr_push;
reg rd_clk;
reg rd_pull;

// Outputs
wire wr_full;
wire [15:0] rd_data;
wire rd_empty;

// Instantiate the Unit Under Test (UUT)
usb_to_sdram uut (
    .rst_n(rst_n), 
    .wr_clk(wr_clk), 
    .wr_addr(wr_addr), 
    .wr_data(wr_data), 
    .wr_en(wr_en), 
    .wr_push(wr_push), 
    .wr_full(wr_full), 
    .rd_clk(rd_clk), 
    .rd_data(rd_data), 
    .rd_pull(rd_pull), 
    .rd_empty(rd_empty)
);

always begin
    rd_clk = 0;
    #2;
    rd_clk = 1;
    #2;
end

always begin
    wr_clk = 0;
    #3;
    wr_clk = 1;
    #3;
end

integer i;

initial begin
    // Initialize Inputs
    rst_n = 0;
    wr_addr = 0;
    wr_data = 0;
    wr_en = 0;
    wr_push = 0;
    rd_pull = 0;

    // Wait 100 ns for global reset to finish
    #100;
    rst_n = 1;
    @(posedge rd_clk);
    @(posedge wr_clk);

    // Add stimulus here
    for (i = 0; i < 32; i = i + 1) begin
        @(posedge wr_clk);
        wr_en = 1;
        wr_addr = i;
        wr_data = i;
    end
    
    @(posedge wr_clk);
    wr_en = 0;
    wr_push = 1;

    @(posedge wr_clk);
    wr_push = 0;
end

initial begin
    @(posedge rst_n);
    @(posedge rd_clk);
    
    while (rd_empty) @(posedge rd_clk);

    @(posedge rd_clk);
    rd_pull = 1;
    while (!rd_empty) @(posedge rd_clk);
    rd_pull = 0;
end
      
endmodule

