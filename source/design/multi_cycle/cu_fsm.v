module cu_fsm #(
    parameter CTRL_WORD_W = 10
) (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output reg        regWrite,
    output reg        regDst,
    output reg        aluSrc,
    output reg [2:0]  aluControl, 
    output reg        branch,  memWrite,    memToReg, 
                      jump,    PCWrite,     PCSrc, 
                      PCEn,    branchTaken, IorD, 
                      IRWrite, aluSrcA,
    output reg [1:0]  aluSrcB,
    output reg        halt
);
    localparam  FETCH    = 4'd0, DECODE        = 4'd1, MEM_ADR   = 4'd2,
                MEM_READ = 4'd3, MEM_WRITEBACK = 4'd4, MEM_WRITE = 4'd5,
                EXECUTE  = 4'd6, ALU_WRITEBACK = 4'd7, BRANCH    = 4'd8;

    localparam  OP_RTYPE = 6'b000000, OP_LW    = 6'b100011, OP_SW    = 6'b101011,
                OP_BEQ   = 6'b000100, OP_BNE   = 6'b000101, OP_ADDI  = 6'b001000,
                OP_ORI   = 6'b001101, OP_JMP   = 6'b000010, OP_ANDI  = 6'b001100,
                OP_LUI   = 6'b001111, OP_HALT  = 6'b111111;

    reg [1:0] state, nstate;
    
    // state transition
    always @* 
        case(state)
            FETCH : nstate = DECODE;
            DECODE: begin
                case (opcode)
                    OP_SW, OP_LW            : nstate = MEM_ADR;
                    OP_RTYPE                : nstate = EXECUTE;
                    OP_BEQ, OP_BNE, OP_BLT  : nstate = BRANCH;
                    default: nstate = FETCH; 
                endcase
            end
        endcase

    // current state storage
    always @(posedge clk)
        if(rst)
            state <= FETCH;
        else
            state <= nstate;

    // outputs generation
    always @* 
        case(state)
            FETCH: begin
                IorD       = 1'b0;      // instruction fetch
                IRWrite    = 1'b1;      // write to instruction register
                PCWrite    = 1'b1;      // update PC
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b01;     // 4 for PC + 4
                aluControl = 3'b010;    // add
                PCSrc      = 1'b0;      // PC + 4
            end
            DECODE: begin
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b11;     // sign-extended immediate << 2 for branch address calculation
                aluControl = 3'b010;    // add (for branch address calculation)
            end
            MEM_ADR: begin
                aluSrcA    = 1'b1;      // rs data as ALU input A
                aluSrcB    = 2'b10;     // sign-extended immediate for memory address calculation
                aluControl = 3'b010;    // add (for memory address calculation)
            end
            MEM_READ: begin
                IorD       = 1'b1;      // data memory access
            end
            MEM_WRITEBACK: begin
            end
            MEM_WRITE: begin
            end
            EXECUTE: begin
            end
            ALU_WRITEBACK: begin
            end
            BRANCH: begin
            end
        endcase

    // always @* begin
    //     halt = 1'b0;
        
    //     case (opcode) 
    //         OP_RTYPE: begin    // R-TYPE INSTRUCTION
    //             case (funct)
    //                 6'b100000: word = 10'b1100100000;   // ADD
    //                 6'b100010: word = 10'b1101100000;   // SUB
    //                 6'b100100: word = 10'b1100000000;   // AND
    //                 6'b100101: word = 10'b1100010000;   // OR
    //                 6'b101010: word = 10'b1101110000;   // SLT  (set on less than)
    //                 6'b000000: word = 10'b1100110000;   // SLL  (shift left logical)
    //                 6'b000010: word = 10'b1101000000;   // SRL  (shift right logical)
    //                 default:   word = 10'b0000000000;
    //             endcase
    //         end
    //         OP_LW:   word = 10'b1010100010;   // LW   (load word)
    //         OP_SW:   word = 10'b0x101001x0;   // SW   (store word)
    //         OP_BEQ:  word = 10'b0x011010x0;   // BEQ  (branch if equal)
    //         OP_BNE:  word = 10'b0x011010x0;   // BNE  (branch if not equal)
    //         OP_BLT:  word = 10'b0x011010x0;   // BLT  (branch if less than)
    //         OP_ADDI: word = 10'b1010100000;   // ADDi (add imm)
    //         OP_ORI:  word = 10'b1010010000;   // ORi  (or imm)
    //         OP_JMP:  word = 10'b0xxxxxxxx1;   // JMP  (jump)
    //         OP_ANDI: word = 10'b1010000000;   // ANDi (and imm)
    //         OP_LUI:  word = 10'b1011010000;   // LUI  (load upper immediate)
    //         OP_HALT: begin
    //             word = 10'b0000000000;          // HALT
    //             halt = 1'b1;
    //         end
    //         default: word = 10'b0000000000;     // NOP or undefined instruction
    //     endcase
    //end
endmodule