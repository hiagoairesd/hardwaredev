module inst_mem #(
    parameter ADDR_W = 8,
    parameter INSTR_W = 32,
    parameter DEPTH  = 256
) (
    input  wire [ADDR_W-1:0] addr_in,
    output wire [INSTR_W-1:0] instr_out
);
    reg [INSTR_W-1:0] mem [0:DEPTH-1];
    assign instr_out = mem[addr_in];
endmodule