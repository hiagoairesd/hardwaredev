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
    output reg        jump,
    output reg        PCWrite,
    output reg        PCSrc,
    output reg        PCEn,
    output reg        branchTaken,
    output reg        IorD,
    output reg        IRWrite,
    output reg        aluSrcA,
    output reg [1:0]  aluSrcB,
    output reg        halt
);
    localparam IDLE = 4'd0,
               FETCH = 4'd1;
    reg [1:0] state, nstate;
    


    always @*
        case(state)
            IDLE:
            FETCH: 
        endcase


    always @(posedge clk)
        if(rst)
            state <= IDLE;
        else
            state <= nstate;







endmodule