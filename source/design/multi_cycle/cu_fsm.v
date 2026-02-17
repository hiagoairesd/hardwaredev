module cu_fsm #(
    parameter CTRL_WORD_W = 10
) (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    input  wire       clk,
    input  wire       rst,

// SELECT SIGNALS
    output reg        memToReg, regDst, IorD, PCSrc, aluSrcA,
    output reg [1:0]  aluSrcB,

// ENABLE SIGNALS
    output reg        IRWrite, memWrite, PCWrite, branch, regWrite,

// CONTROL SIGNALS
    output reg [2:0]  aluControl,
    output reg        jump, halt,        // review if JUMP signal is needed (!!!)
    output reg        aluOp
);
//==============================================================================
// 1) State encoding
//==============================================================================
    localparam  FETCH    = 4'd0, DECODE        = 4'd1, MEM_ADR   = 4'd2,
                MEM_READ = 4'd3, MEM_WRITEBACK = 4'd4, MEM_WRITE = 4'd5,
                EXECUTE  = 4'd6, ALU_WRITEBACK = 4'd7, BRANCH    = 4'd8;

//==============================================================================
// 2) Opcode and funct field encoding
//==============================================================================
    localparam  OP_RTYPE = 6'b000000, OP_LW    = 6'b100011, OP_SW    = 6'b101011,
                OP_BEQ   = 6'b000100, OP_BNE   = 6'b000101, OP_ADDI  = 6'b001000,
                OP_ORI   = 6'b001101, OP_JMP   = 6'b000010, OP_ANDI  = 6'b001100,
                OP_LUI   = 6'b001111, OP_HALT  = 6'b111111;

//==============================================================================
// 3) State transition logic (1st block): combinational logic to determine next state
//==============================================================================
    reg [3:0] state, nstate;

    always @* 
        case(state)
            FETCH : nstate = DECODE;
            DECODE: begin
                case (opcode)
                    OP_SW, OP_LW: nstate = MEM_ADR;
                    OP_RTYPE    : nstate = EXECUTE;
                    default     : nstate = FETCH; 
                endcase
            end
            MEM_ADR: begin
                case(opcode)
                    OP_LW  : nstate = MEM_READ;
                    OP_SW  : nstate = MEM_WRITE;
                    default: nstate = FETCH;
                endcase
            end
            MEM_READ     : nstate = MEM_WRITEBACK;
            MEM_WRITEBACK: nstate = FETCH;
            MEM_WRITE    : nstate = FETCH;
            EXECUTE      : nstate = ALU_WRITEBACK;
            ALU_WRITEBACK: nstate = FETCH;
            BRANCH       :
            default: nstate = FETCH;
        endcase
//==============================================================================
// 4) Current state storage (2nd block): sequential logic to update current state
//==============================================================================
    always @(posedge clk)
        if(rst)
            state <= FETCH;
        else
            state <= nstate;

//==============================================================================
// 5) Output generation (3rd block): combinational logic to generate control signals based on current state
//==============================================================================
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
                aluControl = 3'b010;    // add
                PCSrc      = 1'b0;      // PC + 4
                //------------------------------------------------------------------------------
                memWrite   = 1'b0;      // no memory write      // necessario
                branch     = 1'b0;      // no branch            // declarar?
                regWrite   = 1'b0;      // no register write    //  ?
            end
        //------------------------------------------------------------------------------
        // (S1) Decode state: decode instruction and read registers
            DECODE: begin
                aluSrcA    = 1'b0;      // PC as ALU input A
                aluSrcB    = 2'b11;     // sign-extended immediate << 2 for branch address calculation
                aluControl = 3'b010;    // add (for branch address calculation)
                //------------------------------------------------------------------------------
                memWrite   = 1'b0;      // no memory write                              // necessario
                branch     = 1'b0;      // no branch                                    // declarar?
                regWrite   = 1'b0;      // no register write                            //  ?
                PCWrite    = 1'b0;      // no PC update in decode stage
                IRWrite    = 1'b0;      // no instruction register write in decode stage
            end
        //------------------------------------------------------------------------------
        // (S2) Memory address calculation state: calculate address for load/store
            MEM_ADR: begin
                aluSrcA    = 1'b1;      // rs data as ALU input A
                aluSrcB    = 2'b10;     // sign-extended immediate for memory address calculation
                aluControl = 3'b010;    // add (for memory address calculation)
                //------------------------------------------------------------------------------
                memWrite   = 1'b0;      // no memory write                              // necessario
                branch     = 1'b0;      // no branch                                    // declarar?
                regWrite   = 1'b0;      // no register write                            //  ?
                PCWrite    = 1'b0;      // no PC update in decode stage
                IRWrite    = 1'b0;      // no instruction register write in decode stage
            end
        //------------------------------------------------------------------------------
        // (S3) Memory read state: read data from memory
            MEM_READ: begin
                IorD       = 1'b1;      // data memory access
                //------------------------------------------------------------------------------
                IRWrite    = 1'b0;      // no instruction register write in decode stage
                memWrite   = 1'b0;      // no memory write                              // necessario
                PCWrite    = 1'b0;      // no PC update in decode stage                 // declarar?
                branch     = 1'b0;      // no branch                                    //  ?
                regWrite   = 1'b0;      // no register write                            //  ?
            end
        //------------------------------------------------------------------------------
        // (S4) Memory writeback state: write data back to register
            MEM_WRITEBACK: begin
                memtoReg    = 1'b1;      // select memory data for register writeback
                regDst      = 1'b0;      // select rt as destination register
                regWrite    = 1'b1;      // enable register writeback
                //------------------------------------------------------------------------------
                IRWrite    = 1'b0;      // no instruction register write in decode stage
                memWrite   = 1'b0;      // no memory write                              // necessario
                PCWrite    = 1'b0;      // no PC update in decode stage                 // declarar?
                branch     = 1'b0;      // no branch                                    //  ?
            end
        //------------------------------------------------------------------------------
        // (S5) Memory write state: write data to memory
            MEM_WRITE: begin
                IorD       = 1'b1;      // data memory access
                memWrite   = 1'b1;      // enable memory write
                //------------------------------------------------------------------------------
                IRWrite    = 1'b0;      // no instruction register write in decode stage
                PCWrite    = 1'b0;      // no PC update in decode stage                 // declarar?
                branch     = 1'b0;      // no branch                                    //  ?
                regWrite   = 1'b0;      // no register write                            //
            end
        //------------------------------------------------------------------------------
        // (S6) Execute state: perform ALU operations
            EXECUTE: begin
                aluSrcA    = 1'b1;
                aluSrcB    = 2'b01;
                aluOp      = 2'b10; //??????
                //------------------------------------------------------------------------------
                IRWrite    = 1'b0;      // no instruction register write in decode stage
                memWrite   = 1'b0;      // no memory write                              // necessario
                PCWrite    = 1'b0;      // no PC update in decode stage                 // declarar?
                branch     = 1'b0;      // no branch                                    //  ?
                regWrite   = 1'b0;      // no register write                            //
            end
        //------------------------------------------------------------------------------
        // (S7) ALU writeback state: write ALU result back to register
            ALU_WRITEBACK: begin
                regDst      = 1'b1;      // select rd as destination register
                memtoReg    = 1'b0;      // select ALU result for register writeback
                regWrite    = 1'b1;      // enable register writeback
                //------------------------------------------------------------------------------
                IRWrite    = 1'b0;      // no instruction register write in decode stage
                memWrite   = 1'b0;      // no memory write                              // necessario
                PCWrite    = 1'b0;      // no PC update in decode stage                 // declarar?
                branch     = 1'b0;      // no branch                                    //
            end
        //------------------------------------------------------------------------------
        // (S8) Branch state: evaluate branch condition and update PC if needed
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


    always @* begin
        case(aluOp)
            2'b00: aluControl = 3'b010; // add (for lw/sw address calculation and addi)
            2'b01: aluControl = 3'b110; // sub (for beq)
            2'b10: begin
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