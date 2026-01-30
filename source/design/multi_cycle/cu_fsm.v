module cu_fsm #(
    parameter CTRL_WORD_W = 10
) (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output reg        regWrite,
    output reg        regDst,
    output reg        aluSrc,
    output reg [2:0]  aluControl,
    output reg        branch,
    output reg        memWrite,
    output reg        memToReg,
    output reg        jump
);
endmodule