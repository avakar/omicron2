module system(
    input rst_n,
    input clk,

    output io_addr_strobe,
    output io_read_strobe,
    output io_write_strobe,

    output[31:0] io_addr,
    output[3:0] io_byte_enable,
    output[31:0] io_write_data,
    input[31:0] io_read_data,
    input io_ready
    );

axi_cpu cpu0(
    .rst_n(rst_n),
    .clk(clk),

    .io_addr_strobe(io_addr_strobe),
    .io_read_strobe(io_read_strobe),
    .io_write_strobe(io_write_strobe),

    .io_addr(io_addr),
    .io_byte_enable(io_byte_enable),
    .io_write_data(io_write_data),
    .io_read_data(io_read_data),
    .io_ready(io_ready)
    );

endmodule
