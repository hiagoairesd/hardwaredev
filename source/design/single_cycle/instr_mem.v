module instr_mem #(
    parameter ADDR_W = 8,
    parameter INSTR_W = 32,
    parameter DEPTH  = 256
) (
    input  wire [ADDR_W-1:0 ] addr_in,
    output wire [INSTR_W-1:0] instr_out
);
    reg [INSTR_W-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i +1) begin
            mem[i] = {INSTR_W{1'b0}};
        end
    end
    assign instr_out = mem[addr_in];
endmodule