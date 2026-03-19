module control_unit #(
    parameter INSTR_W = 32
) (
    input wire  [5:0] opcode,
    input wire  [5:0] funct,
    input wire        aluOut_is_zero,
    input wire        signed_less,
    output wire [2:0] aluControl,
    output wire       regWrite, regDst, aluSrc, take_branch, memWrite, memtoReg, jump, is_shift, imm_is_zext,
    output reg        halt
);
    //==================================================================================
    // 1) Opcode and funct field encoding
    //==================================================================================
    localparam  OP_RTYPE = 6'b000000, OP_LW    = 6'b100011, OP_SW    = 6'b101011,
                OP_BEQ   = 6'b000100, OP_BNE   = 6'b000101, OP_BLT   = 6'b000110,
                OP_ADDI  = 6'b001000, OP_ORI   = 6'b001101, OP_ANDI  = 6'b001100, 
                OP_LUI   = 6'b001111, OP_JUMP  = 6'b000010, OP_HALT  = 6'b111111;
    
    localparam  FNCT_SLL = 6'b000000, FNCT_SRL = 6'b000010, FNCT_ADD = 6'b100000,
                FNCT_SUB = 6'b100010, FNCT_AND = 6'b100100, FNCT_OR  = 6'b100101, 
                FNCT_SLT = 6'b101010;
    //==================================================================================
    // 2) Control signal generation based on opcode and funct fields
    //==================================================================================

    always @* begin
        halt = 1'b0;
        
        case (opcode) 
            OP_RTYPE: begin    // R-TYPE INSTRUCTION
                case (funct)
                    FNCT_ADD: word = 10'b1100100000;   // ADD
                    FNCT_SUB: word = 10'b1101100000;   // SUB
                    FNCT_AND: word = 10'b1100000000;   // AND
                    FNCT_OR : word = 10'b1100010000;   // OR
                    FNCT_SLT: word = 10'b1101110000;   // SLT  (set on less than)
                    FNCT_SLL: word = 10'b1100110000;   // SLL  (shift left logical)
                    FNCT_SRL: word = 10'b1101000000;   // SRL  (shift right logical)
                    default:  word = 10'b0000000000;
                endcase
            end
            OP_LW  : word = 10'b1010100010;     // LW   (load word)
            OP_SW  : word = 10'b0x101001x0;     // SW   (store word)
            OP_BEQ : word = 10'b0x011010x0;     // BEQ  (branch if equal)
            OP_BNE : word = 10'b0x011010x0;     // BNE  (branch if not equal)
            OP_BLT : word = 10'b0x011010x0;     // BLT  (branch if less than)
            OP_ADDI: word = 10'b1010100000;     // ADDi (add imm)
            OP_ORI : word = 10'b1010010000;     // ORi  (or imm)
            OP_JUMP: word = 10'b0xxxxxxxx1;     // JMP  (jump)
            OP_ANDI: word = 10'b1010000000;     // ANDi (and imm)
            OP_LUI : word = 10'b1011010000;     // LUI  (load upper immediate)
            OP_HALT: begin
                word = 10'b0000000000;          // HALT
                halt = 1'b1;
            end
            default: word = 10'b0000000000;     // NOP or undefined instruction
        endcase
    end

    assign {regWrite, regDst, aluSrc, aluControl, branch, memWrite, memtoReg, jump} = word;

    //==================================================================================
    // 8) Branch handling: determine if we should take the branch based on opcode and ALU outputs
    //==================================================================================
    //   - is_bne is true for BNE opcode (000101)
    //   - is_blt is true for BLT opcode (000110)
    //   - is_beq is true for BEQ opcode (000100)
    //   - is_zero comes from ALU compare (typically subtraction result == 0)
    //   - For BEQ: take_branch when is_zero==1
    //   - For BNE: take_branch when is_zero==0
    //   - For BLT: take_branch when signed_less==1
    wire is_beq = (opcode == OP_BEQ);
    wire is_bne = (opcode == OP_BNE);
    wire is_blt = (opcode == OP_BLT);

    assign take_branch = (is_beq && aluOut_is_zero ) |
                         (is_bne && ~aluOut_is_zero) |
                         (is_blt && signed_less);

    //==================================================================================
    // 9) Special case handling for shift instructions: determine if current instruction is a shift and adjust control signals accordingly
    //================================================================================

    assign is_shift = (opcode == OP_RTYPE) &
                      (funct  == FNCT_SLL  | funct == FNCT_SRL);
    // For shift instructions, we need to use the shamt field as ALU input instead of the register value. 
    // This requires a special case in the control logic to select the correct ALU input.
    // Immediate extension policy:

    //   - ANDI/ORI/LUI use zero-extend
    //   - others use sign-extend
    assign imm_is_zext =
        (opcode == OP_ANDI) |
        (opcode == OP_ORI ) |
        (opcode == OP_LUI );
endmodule