module fsm_cu #(
    parameter CTRL_WORD_W = 10
) (
    input wire        clk,
    input wire        rst,
    input wire [31:0] instr,                // full instruction word (for opcode and funct fields)
    input wire        aluOut_is_zero,       // ALU zero flag

    output wire PCEn,                       // PC enable signal (for PC update)

// SELECT SIGNALS
    output reg        memToReg, regDst, IorD, aluSrcA,
    output reg [1:0]  aluSrcB,  PCSrc,

// ENABLE SIGNALS
    output reg        IRWrite, memWrite, PCWrite, branch, regWrite,

// CONTROL SIGNALS
    output reg [2:0]  aluControl,
    output reg        halt
);
//=================================================================================
// 1) State encoding
//=================================================================================
    localparam  FETCH          = 4'd0, DECODE        = 4'd1,  MEM_ADR   = 4'd2,
                MEM_READ       = 4'd3, MEM_WRITEBACK = 4'd4,  MEM_WRITE = 4'd5,
                EXECUTE        = 4'd6, ALU_WRITEBACK = 4'd7,  BEQ       = 4'd8,
                ADDI_WRITEBACK = 4'd9, JUMP          = 4'd10, HALT      = 4'd11;

//==================================================================================
// 2) Opcode and funct field encoding
//==================================================================================
    localparam  OP_RTYPE = 6'b000000, OP_LW    = 6'b100011, OP_SW    = 6'b101011,
                OP_BEQ   = 6'b000100, OP_BNE   = 6'b000101, OP_ADDI  = 6'b001000,
                OP_ORI   = 6'b001101, OP_JMP   = 6'b000010, OP_ANDI  = 6'b001100,
                OP_LUI   = 6'b001111, OP_ADDI  = 6'b001000, OP_JUMP  = 6'b000010, 
                OP_HALT  = 6'b111111;

//==================================================================================
// 3) Internal signals for instruction decoding and control logic
//==================================================================================
    wire [5:0] opcode;
    wire [5:0] funct;

//===================================================================================
// 4) State transition logic (1st block): combinational logic to determine next state
//===================================================================================
    reg [3:0] state, nstate;
    always @* 
        case(state)
            FETCH : nstate = DECODE;
            DECODE: begin
                case (opcode)
                    OP_SW, OP_LW: nstate = MEM_ADR;
                    OP_RTYPE    : nstate = EXECUTE;
                    OP_BEQ      : nstate = BEQ;
                    OP_JUMP     : nstate = JUMP;
                    OP_HALT     : nstate = HALT;
                    default     : nstate = FETCH;
                endcase
            end
            MEM_ADR: begin
                case(opcode)
                    OP_LW  : nstate = MEM_READ;
                    OP_SW  : nstate = MEM_WRITE;
                    OP_ADDI: nstate = ADDI_WRITEBACK;
                    default: nstate = FETCH;
                endcase
            end
            MEM_READ      : nstate = MEM_WRITEBACK;
            MEM_WRITEBACK : nstate = FETCH;
            MEM_WRITE     : nstate = FETCH;
            EXECUTE       : nstate = ALU_WRITEBACK;
            ALU_WRITEBACK : nstate = FETCH;
            BEQ           : nstate = FETCH;
            ADDI_WRITEBACK: nstate = FETCH;
            JUMP          : nstate = FETCH;
            HALT          : nstate = HALT;
            default: nstate = FETCH;
        endcase
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
    always @* 
        case(state)
        //------------------------------------------------------------------------------
        // (S0) Fetch state: fetch instruction from memory
            FETCH: begin
                IorD       = 1'b0;      // instruction fetch
                IRWrite    = 1'b1;      // write to instruction register
                PCWrite    = 1'b1;      // update PC
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b01;     // 4 for PC + 4
                aluOp      = 2'b00;     // add
                PCSrc      = 2'b00;     // PC + 4
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
                memtoReg    = 1'b1;      // select memory data for register writeback
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
                memtoReg    = 1'b0;      // select ALU result for register writeback
                regWrite    = 1'b1;      // enable register writeback
                IRWrite     = 1'b0;
                memWrite    = 1'b0;
                PCWrite     = 1'b0;
                branch      = 1'b0;
            end
        //------------------------------------------------------------------------------
        // (S8) Branch state: evaluate branch condition and update PC if needed
            BEQ: begin
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
        // (S9) ADDI writeback state: write addi result back to register
            ADDI_WRITEBACK: begin
                regDst      = 1'b0;      // select rt as destination register for addi
                memtoReg    = 1'b0;      // select ALU result for register writeback
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
        // (S11) HALT state: set halt signal and disable all other operations
            HALT: begin
                halt       = 1'b1;          // set halt signal in HALT state
                IRWrite    = 1'b0;
                memWrite   = 1'b0;
                PCWrite    = 1'b0;
                branch     = 1'b0;
                regWrite   = 1'b0;
            end
        endcase
//==============================================================================
// 7) ALU control logic: combinational logic to generate ALU control signals based on opcode and funct fields
//==============================================================================
    always @* begin
        case(aluOp)
            2'b00: aluControl = 3'b010; // add (for lw/sw address calculation and addi)
            2'b01: aluControl = 3'b110; // sub (for beq)
            2'b1x: begin
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
            end
            default: aluControl = 3'b000; // default to AND for undefined aluOp
        endcase
    end
endmodule
//==================================================================================
// 8) PC update logic: combinational logic to determine when to update PC based on control signals and ALU zero flag
//==================================================================================
    assign PCEn = PCWrite | (branch & zero);