module control_unit #(
    parameter INSTR_W = 32
) (
    input wire              clk,
    input wire              rst,
    input wire [INSTR_W-1:0] instr,           // full instruction word (for opcode and funct fields)
    input wire              aluOut_is_zero,  // ALU zero flag
    input wire              signed_less,     // ALU signed less flag

    output wire PCEn,                        // PC enable signal for program counter update
    output wire is_shift, imm_is_zext,       // signals for shift instructions and immediate extension policy

// SELECT SIGNALS
    output reg       memToReg,              // select signal for register writeback data (0: ALU result, 1: memory data)
    output reg       regDst,                // select signal for destination register (0: rt, 1: rd)
    output reg       IorD,                  // select signal for memory address source (0: PC, 1: ALU result)
    output reg       aluSrcA,               // select signal for ALU input A (0: PC, 1: register data)
    output reg [1:0] aluSrcB,               // select signal for ALU input B (00: register data | 01: 4 | 10: sign-extended immediate | 11: sign-extended immediate << 2)
    output reg [1:0] PCSrc,                 // select signal for PC source (00: PC+4 | 01: branch target | 10: jump target)

// ENABLE SIGNALS
    output reg       IRWrite,               // instruction register write enable
    output reg       memWrite,              // memory write enable
    output reg       PCWrite,               // PC write enable (for jumps and branches)
    output reg       regWrite,              // register file write enable

// CONTROL SIGNALS
    output reg [2:0]  aluControl,           // ALU control signal (to select ALU operation)
    output reg        halt                  // signal to indicate halt instruction has been executed
);
//=================================================================================
// 1) State encoding
//=================================================================================
    localparam  FETCH          = 4'd0, DECODE        = 4'd1,  MEM_ADR     = 4'd2,
                MEM_READ       = 4'd3, MEM_WRITEBACK = 4'd4,  MEM_WRITE   = 4'd5,
                EXECUTE        = 4'd6, ALU_WRITEBACK = 4'd7,  BRANCH      = 4'd8,
                IMM_WRITEBACK  = 4'd9, JUMP          = 4'd10, EXECUTE_IMM = 4'd11,
                HALT           = 4'd12;

//==================================================================================
// 2) Opcode and funct field encoding
//==================================================================================
    localparam  OP_RTYPE = 6'b000000, OP_LW    = 6'b100011, OP_SW    = 6'b101011,
                OP_BEQ   = 6'b000100, OP_BNE   = 6'b000101, OP_BLT   = 6'b000110,
                OP_ADDI  = 6'b001000, OP_ORI   = 6'b001101, OP_ANDI  = 6'b001100, 
                OP_LUI   = 6'b001111, OP_JUMP  = 6'b000010, OP_HALT  = 6'b111111;

    localparam  FNCT_SLL = 6'b000000, FNCT_SRL = 6'b000010;

//==================================================================================
// 3) Internal signals for instruction decoding and control logic
//==================================================================================
    wire [5:0] opcode = instr[INSTR_W-1:INSTR_W-6];
    wire [5:0] funct  = instr[5:0];
    reg  [1:0] aluOp;                   // ALU operation code for ALU control logic
    reg        branch;
//===================================================================================
// 4) State transition logic (1st block): combinational logic to determine next state
//===================================================================================
    reg [3:0] state, nstate;
    always @* begin
        case(state)
            FETCH : nstate = DECODE;
            DECODE: begin
                case (opcode)
                    OP_SW, OP_LW    : nstate = MEM_ADR;
                    OP_RTYPE        : nstate = EXECUTE;
                    OP_BEQ, OP_BNE,
                    OP_BLT          : nstate = BRANCH;
                    OP_ADDI, OP_ORI,
                    OP_ANDI, OP_LUI : nstate = EXECUTE_IMM;
                    OP_JUMP         : nstate = JUMP;
                    OP_HALT         : nstate = HALT;
                    default         : nstate = FETCH;
                endcase
            end
            MEM_ADR: begin
                case(opcode)
                    OP_LW  : nstate = MEM_READ;
                    OP_SW  : nstate = MEM_WRITE;
                    OP_ADDI: nstate = IMM_WRITEBACK;
                    default: nstate = FETCH;
                endcase
            end
            MEM_READ      : nstate = MEM_WRITEBACK;
            MEM_WRITEBACK : nstate = FETCH;
            MEM_WRITE     : nstate = FETCH;
            EXECUTE       : nstate = ALU_WRITEBACK;
            ALU_WRITEBACK : nstate = FETCH;
            BRANCH        : nstate = FETCH;
            IMM_WRITEBACK: nstate = FETCH;
            JUMP          : nstate = FETCH;
            EXECUTE_IMM   : nstate = IMM_WRITEBACK;
            HALT          : nstate = HALT;
            default: nstate = FETCH;
        endcase
    end
//=================================================================================
// 5) Current state storage (2nd block): sequential logic to update current state
//=================================================================================
    always @(posedge clk)
        if(rst)
            state <= FETCH;
        else
            state <= nstate;

//=================================================================================
// 6) Output generation (3rd block): combinational logic to generate control signals based on current state
//=================================================================================
    always @* begin
        {memToReg, regDst, IorD, aluSrcA, aluSrcB, PCSrc, IRWrite, memWrite, PCWrite, regWrite, aluOp, branch, halt} = 16'b0000000000000000;
        case(state)
        //------------------------------------------------------------------------------
        // (S0) Fetch state: fetch instruction from memory
            FETCH: begin
                IorD       = 1'b0;      // instruction fetch
                IRWrite    = 1'b1;      // write to instruction register
                PCWrite    = 1'b1;      // update PC
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b01;     // 4 as ALU input B (for PC + 4)
                aluOp      = 2'b00;     // add
                PCSrc      = 2'b00;     // PC = PC + 4
                memWrite   = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S1) Decode state: decode instruction and read registers
            DECODE: begin
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b11;     // sign-extended immediate << 2 for branch address calculation
                aluOp      = 2'b00;     // add (for branch address calculation)
                memWrite   = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
                PCWrite    = 1'b0;
                IRWrite    = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S2) Memory address calculation state: calculate address for load/store
            MEM_ADR: begin
                aluSrcA    = 1'b1;      // rs data as ALU input A
                aluSrcB    = 2'b10;     // sign-extended immediate for memory address calculation
                aluOp      = 2'b00;     // add (for memory address calculation)
                memWrite   = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
                PCWrite    = 1'b0;
                IRWrite    = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S3) Memory read state: read data from memory
            MEM_READ: begin
                IorD       = 1'b1;      // data memory access
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S4) Memory writeback state: write data back to register
            MEM_WRITEBACK: begin
                memToReg    = 1'b1;      // select memory data for register writeback
                regDst      = 1'b0;      // select rt as destination register
                regWrite    = 1'b1;      // enable register writeback
                IRWrite     = 1'b0;
                memWrite    = 1'b0;
                PCWrite     = 1'b0;
                branch      = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S5) Memory write state: write data to memory
            MEM_WRITE: begin
                IorD       = 1'b1;      // data memory access
                memWrite   = 1'b1;      // enable memory write
                IRWrite    = 1'b0;
                PCWrite    = 1'b0; 
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S6) Execute state: perform ALU operations
            EXECUTE: begin
                aluSrcA    = 1'b1;      // rs data as ALU input A
                aluSrcB    = 2'b00;     // rt data as ALU input B
                aluOp      = 2'b10; 
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S7) ALU writeback state: write ALU result back to register
            ALU_WRITEBACK: begin
                regDst      = 1'b1;      // select rd as destination register
                memToReg    = 1'b0;      // select ALU result for register writeback
                regWrite    = 1'b1;      // enable register writeback
                IRWrite     = 1'b0;
                memWrite    = 1'b0;
                PCWrite     = 1'b0;
                branch      = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S8) Branch state: evaluate branch condition and update PC if needed
            BRANCH: begin
                aluSrcA    = 1'b1;      // rs data as ALU input A
                aluSrcB    = 2'b00;     // rt data as ALU input B
                aluOp      = 2'b01;     // sub (for branch comparison)
                PCSrc      = 2'b01;     // select branch target address for PC update if branch taken
                branch     = 1'b1;      // enable branch decision
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S9) Immediate writeback state: write immediate result back to register
            IMM_WRITEBACK: begin
                regDst      = 1'b0;      // select rt as destination register for immediate instructions
                memToReg    = 1'b0;      // select ALU result for register writeback
                regWrite    = 1'b1;      // enable register writeback
                IRWrite     = 1'b0;
                memWrite    = 1'b0;
                PCWrite     = 1'b0;
                branch      = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S10) Jump state: update PC to jump target address
            JUMP: begin
                PCSrc      = 2'b10;     // select jump target address for PC update
                PCWrite    = 1'b1;      // enable PC update for jump
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S11) Execute immediate state: perform ALU operation with immediate value
            EXECUTE_IMM: begin
                aluSrcA    = 1'b1;
                aluSrcB    = 2'b10;     // select sign-extended immediate for ALU input B
                aluOp      = 2'b10;
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S12) HALT state: set halt signal and disable all other operations
            HALT: begin
                halt       = 1'b1;          // set halt signal in HALT state
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        endcase
    end
//==============================================================================
// 7) ALU control logic: combinational logic to generate ALU control signals based on opcode and funct fields
//==============================================================================
    always @* begin
        casez(aluOp)
            2'b00: aluControl = 3'b010; // add (for lw/sw address calculation and addi)
            2'b01: aluControl = 3'b110; // sub (for beq)
            2'b1?: begin
                if (opcode == OP_RTYPE) begin
                    case(funct)
                        6'b100000: aluControl = 3'b010; // ADD
                        6'b100010: aluControl = 3'b110; // SUB
                        6'b100100: aluControl = 3'b000; // AND
                        6'b100101: aluControl = 3'b001; // OR
                        6'b101010: aluControl = 3'b111; // SLT
                        6'b000000: aluControl = 3'b011; // SLL
                        6'b000010: aluControl = 3'b100; // SRL
                        default:   aluControl = 3'b000; // default to AND for undefined funct
                    endcase
                end else begin
                    case(opcode)
                        OP_ADDI: aluControl = 3'b010;
                        OP_ANDI: aluControl = 3'b000;
                        OP_ORI : aluControl = 3'b001;
                        OP_LUI : aluControl = 3'b101;
                        default: aluControl = 3'b000;
                    endcase
                end
            end
            default: aluControl = 3'b000; // default to AND for undefined aluOp
        endcase
    end

//==================================================================================
// 8) PC update logic: combinational logic to determine when to update PC based on control signals and ALU zero flag
//==================================================================================
    
    wire is_beq = (opcode == OP_BEQ);
    wire is_bne = (opcode == OP_BNE);
    wire is_blt = (opcode == OP_BLT);

    wire take_branch = (is_beq && aluOut_is_zero ) |
                       (is_bne && ~aluOut_is_zero) |
                       (is_blt && signed_less);

    assign PCEn = PCWrite | (branch & take_branch);


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