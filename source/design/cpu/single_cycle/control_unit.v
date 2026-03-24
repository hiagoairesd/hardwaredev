module control_unit (
    input wire  [31:0]instr,            // Current instruction
    input wire        aluOut_is_zero,   // ALU output zero flag for branch decisions
    input wire        signed_less,      // ALU output signed less-than flag for BLT instruction
    output wire [2:0] aluControl,       // ALU control signal
    output wire       regWrite,         // Register file write enable
    output wire       regDst,           // Register destination select (0=rt, 1=rd)
    output wire       aluSrc,           // ALU source select (0=register, 1=immediate)
    output wire       take_branch,      // Branch taken signal for BEQ/BNE/BLT
    output wire       memWrite,         // Memory write enable for SW instruction
    output wire       memtoReg,         // Memory to register select (0=memory, 1=ALU)
    output wire       jump,             // Jump signal for J instruction
    output wire       is_shift,         // Shift signal for SLL/SRL instructions
    output wire       imm_is_zext,      // Immediate zero-extension signal
    output reg        halt              // Halt signal
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
    // 2) Word Control signal generation based on instruction opcode and funct fields
    //==================================================================================
    wire [5:0] opcode = instr[31:26];   // opcode field from instruction
    wire [5:0] funct  = instr[5:0];     // funct field for R-type instructions (ignored for non-R-type)
    reg  [8:0] word;

    always @* begin
        halt = 1'b0;
        
        case (opcode) 
            OP_RTYPE: begin
                case (funct)
                    FNCT_ADD: word = 9'b110010000;
                    FNCT_SUB: word = 9'b110110000;
                    FNCT_AND: word = 9'b110000000;
                    FNCT_OR : word = 9'b110001000;
                    FNCT_SLT: word = 9'b110111000;
                    FNCT_SLL: word = 9'b110011000;
                    FNCT_SRL: word = 9'b110100000;
                    default:  word = 9'b000000000;
                endcase
            end
            OP_LW  : word = 9'b101010010;
            OP_SW  : word = 9'b001010100;
            OP_BEQ : word = 9'b000110000;
            OP_BNE : word = 9'b000110000;
            OP_BLT : word = 9'b000110000;
            OP_ADDI: word = 9'b101010000;
            OP_ORI : word = 9'b101001000;
            OP_JUMP: word = 9'b000000001;
            OP_ANDI: word = 9'b101000000;
            OP_LUI : word = 9'b101101000;
            OP_HALT: begin
                halt = 1'b1;
                word = 9'b000000000;
            end
            default: word = 9'b000000000;
        endcase
    end

    assign {regWrite, regDst, aluSrc, aluControl, memWrite, memtoReg, jump} = word;

    //============================================================================================
    // 3) Branch handling: determine if we should take the branch based on opcode and ALU outputs
    //============================================================================================
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

    //====================================================================================================================================
    // 4) Special case handling for shift instructions: determine if current instruction is a shift and adjust control signals accordingly
    //====================================================================================================================================

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