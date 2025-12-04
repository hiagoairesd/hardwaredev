module inst_mem #(
    parameter AWIDTH = 8
    parameter DWIDTH = 32
    parameter DEPTH  = 256;
) (
    input wire [DWIDTH-1:0] addr_in,
    output wire [DWIDTH-1:0] instruction_out,
);

    reg [DWIDTH-1:0] mem [0:DEPTH-1];

endmodule