module memory #(
    parameter DATA_W  = 32,
    parameter ADDR_W  = 32
)(
    input wire clk,
    input wire we,
    input wire [ADDR_W-1:0] addr,
    input wire [DATA_W-1:0] data_in,
    output reg [DATA_W-1:0] data_out
);
endmodule