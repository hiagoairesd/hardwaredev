module cpu_top#(
    parameter DATA_W = 32,
    parameter ADDR_W = 8
)(
    input wire clk,
    input wire rst,
    output wire halted
);
//==============================================================================
// 1) Local parameters (ISA constants / widths)
//==============================================================================



//==============================================================================
// 2) Architectural state (PC) + halt interface
//==============================================================================
// Halt signal from control unit; exported as output 'halted'
    wire halt;

// Program counter is byte-indexed (DATA_W bits)
    reg  [ADDR_W-1:0] pc;
    wire [ADDR_W-1:0] pc_next;      // Next PC value after selection logic
    wire [1:0]        PCSrc;        // PC source selection for next PC value
    wire [ADDR_W-1:0] PCJump;       // Jump target address for J-type instructions
    wire PCWrite;
    wire PCEn;

    assign PCJump = {pc[31:28], addr, 2'b00};    // Jump target address for J-type instructions
    assign pc_next = 
        (PCSrc == 2'b00) ? alu_out :   
        (PCSrc == 2'b01) ? alu_reg : 
        (PCSrc == 2'b10) ? PCJump  : alu_out;
    assign halted = halt;

// PC update policy:
//   - reset forces PC=0
//   - when halt is asserted, PC stops updating (freezes at current value)
    always @(posedge clk) begin
        if(rst)
            pc <= {ADDR_W{1'b0}};
        else if(PCEn)
            pc <= pc_next;
    end

//==============================================================================
// 5) Memory
//==============================================================================
    wire IorD;  // instruction or data fetch from memory selection
    wire [DATA_W-1:0] mem_out;       // memory output
    wire [ADDR_W-1:0] mem_addr = (IorD)? alu_reg : pc;
// memory address selection: 1 for data, 0 for instruction

    wire [ADDR_W-1:0] mem_addr_word = mem_addr[ADDR_W+1:2]; // word-aligned address

    wire [DATA_W-1:0] mem_data_in = rf_regB;

    memory memory_inst (
        .clk        (clk),
        .we         (memWrite),
        .addr       (mem_addr_word),
        .data_in    (mem_data_in),
        .data_out   (mem_out)
    );

//------------------------------------------------------------------------------
// Non-Architectural Instruction Register logic
    reg [DATA_W-1:0] instr;
    wire IRWrite;

    always @(posedge clk) begin
        if (rst)
            instr <= {DATA_W{1'b0}};
        else if (IRWrite)
            instr <= mem_out;
    end

//------------------------------------------------------------------------------
// Non-Architectural Memory Data Register logic
    reg [DATA_W-1:0] mem_reg;   // data read from memory

    always @(posedge clk) begin
        if (rst)
            mem_reg <= {DATA_W{1'b0}};
        else
            mem_reg <= mem_out;
    end

//==============================================================================
// 4) Instruction fields + immediate extension
//==============================================================================
// Decode fields (MIPS-like format)
    wire [5:0]  opcode = instr[DATA_W-1:26];
    wire [4:0]  rs     = instr[25:21];
    wire [4:0]  rt     = instr[20:16];
    wire [4:0]  rd     = instr[15:11];
    wire [4:0]  shamt  = instr[10:6];
    wire [5:0]  funct  = instr[5:0];
    wire [15:0] imm    = instr[15:0];
    wire [25:0] addr   = instr[25:0];
    wire imm_is_zext;                           // Immediate zero-extension control signal from control unit

    wire [DATA_W-1:0] imm_ext =
        imm_is_zext ? {16'b0, imm} : {{16{imm[15]}}, imm};

//==============================================================================
// 4) Control unit interface + control word breakdown
//==============================================================================
// Control word mapping (MSB..LSB):
    wire       regWrite;            //   [9] regWrite
    wire       regDst;              //   [8] regDst 
    wire       aluSrc;              //   [7] aluSrc
    wire [2:0] aluControl;          //   [6:4] aluControl
    wire       branch;              //   [3] branch
    wire       memWrite;            //   [2] memWrite
    wire       memtoReg;            //   [1] memtoReg
    wire       jump;                //   [0] jump

    fsm_cu fsm_cu_inst (
        .clk            (clk),
        .rst            (rst),
        .instr          (instr),
        .aluOut_is_zero (is_zero),
        .signed_less    (signed_less),
        .PCEn           (PCEn),
        .is_shift       (is_shift),
        .imm_is_zext    (imm_is_zext),
        .memToReg       (memtoReg),
        .regDst         (regDst),
        .IorD           (IorD),
        .aluSrcA        (aluSrcA),
        .aluSrcB        (aluSrcB),
        .PCSrc          (PCSrc),
        .IRWrite        (IRWrite),
        .memWrite       (memWrite),
        .PCWrite        (PCWrite),
        .branch         (branch),
        .regWrite       (regWrite),
        .aluControl     (aluControl),
        .halt           (halt)
    );

//==============================================================================
// 5) Register file (read + writeback selection)
//==============================================================================
    wire [4:0] wa3 = (regDst) ? rd : rt;

    wire [DATA_W-1:0] rf_data_out1;
    wire [DATA_W-1:0] rf_data_out2;
    wire [DATA_W-1:0] rf_wdata;

    register_file rf_inst(
        .clk        (clk),
        .rst        (rst),
        .we3        (regWrite),
        .rd1        (rs),           //A1
        .rd2        (rt),           //A2   
        .wa3        (wa3),          //A3
        .data_in    (rf_wdata),
        .data_out1  (rf_data_out1),
        .data_out2  (rf_data_out2)
    );
// Writeback:
//   - memtoReg=1 selects mem_reg (load)
//   - memtoReg=0 selects alu_out
    assign rf_wdata = (memtoReg)? mem_reg : alu_out;

//------------------------------------------------------------------------------
// Non-Architectural Register File output register logic
    reg [DATA_W-1:0] rf_regA;     // "A" register
    reg [DATA_W-1:0] rf_regB;     // "B" register

    always @(posedge clk) begin
        if (rst) begin
            rf_regA <= {DATA_W{1'b0}};
            rf_regB <= {DATA_W{1'b0}};
        end else begin
            rf_regA <= rf_data_out1;
            rf_regB <= rf_data_out2;
        end
    end

//==============================================================================
// 6) ALU operand selection + ALU execution
//==============================================================================
    wire aluSrcA;
    wire [1:0] aluSrcB;
    wire is_shift;

// ALU operand A:
//   - aluSrcA=1 selects PC
//   - aluSrcA=0 selects rs data
    wire [DATA_W-1:0] alu_a = 
        (aluSrcA == 0) ? pc                          :       
        (is_shift)     ? {{(DATA_W-5){1'b0}}, shamt} : 
                         rf_regA;

// ALU operand B:
//   - aluSrcB=0 selects rt data
//   - aluSrcB=1 selects 4
//   - aluSrcB=2 selects imm_ext
//   - aluSrcB=3 selects imm_ext << 2
    wire [DATA_W-1:0] alu_b =
        (aluSrcB == 2'b00) ? rf_regB                     :
        (aluSrcB == 2'b01) ? {{(DATA_W-3){1'b0}}, 3'd4}  :
        (aluSrcB == 2'b10) ? imm_ext                     : 
                             (imm_ext << 2); // (aluSrcB == 2'b11)

    wire [DATA_W-1:0] alu_out;
    wire              is_zero;
    wire              signed_less;

    alu alu_inst (
        .aluControl (aluControl),
        .in_a       (alu_a),
        .in_b       (alu_b),
        .out        (alu_out),
        .is_zero    (is_zero),
        .signed_less(signed_less)
    );

//------------------------------------------------------------------------------
// Non-Architectural ALU output register logic
    reg [DATA_W-1:0] alu_reg;

    always @(posedge clk) begin
        if (rst)
            alu_reg <= {DATA_W{1'b0}};
        else
            alu_reg <= alu_out;
    end
endmodule
    