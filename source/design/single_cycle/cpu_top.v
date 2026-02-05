//==============================================================================
// cpu_top.sv
//
// Module: cpu_top
// Type  : MIPS-like single-cycle CPU top (PC-indexed instruction memory)
//
// PURPOSE
//   - Connects instruction memory, control unit, register bank, ALU, and data memory
//   - Implements PC update (pc_next selection) and architectural state updates
//   - Exposes 'halted' when Control Unit detects HALT instruction
//
// ASSUMPTIONS / CONTRACT (IMPORTANT)
//   - PC is word-indexed: increments by 1 per instruction (pc_plus1 = pc + 1)
//   - Branch target uses pc_plus1 + imm_ext[ADDR_W-1:0] (low bits of immediate)
//   - Jump target uses instr[ADDR_W-1:0] (low bits of instruction)
//   - Memory addressing uses word index (addr = alu_out[ADDR_W-1:0])
//   - Halt behavior:
//       * control_unit asserts 'halt' to stop PC updates
//       * output 'halted' mirrors 'halt'
//
// NOTES / DESIGN CHOICES
//   - 'dm_data' is modeled as a tri-state bus:
//       * when memWrite=1, CPU drives dm_data with rb_data_out2 (store data)
//       * otherwise dm_data = Z (data_mem is expected to drive for loads)
//   - Shift instructions:
//       * ALU input A uses shamt (zero-extended) when instruction is shift
//       * ALU input B is selected by aluSrc (imm_ext vs rb_data_out2)
//
// DEBUG OBSERVABILITY
//   - Internal signals are named to be waveform-friendly:
//       pc, pc_next, instr, opcode, rs/rt/rd, imm_ext
//       regWrite, memWrite, memtoReg, branch, jump, take_branch
//       write_reg, rb_wdata, alu_out, is_zero, dm_data
//==============================================================================

module cpu_top #(
    parameter int ADDR_W = 8,
    parameter int DATA_W = 32
)(
    input  wire clk,
    input  wire rst,
    output wire halted
);

    //==============================================================================
    // 1) Local parameters (ISA constants / widths)
    //==============================================================================

    localparam int INSTR_W     = 32;
    localparam int CTRL_WORD_W = 10;

    // I-type opcodes used for immediate-extension policy
    localparam [5:0] OP_ANDI = 6'b001100;
    localparam [5:0] OP_ORI  = 6'b001101;
    localparam [5:0] OP_LUI  = 6'b001111;

    // R-type funct codes used for shift detection
    localparam [5:0] FUNCT_SRL = 6'b000010;
    localparam [5:0] FUNCT_SLL = 6'b000000;

    //==============================================================================
    // 2) Architectural state (PC) + halt interface
    //==============================================================================

    // Halt signal from control unit; exported as output 'halted'
    wire halt;
    assign halted = halt;

    // Program counter is word-indexed (ADDR_W bits)
    reg  [ADDR_W-1:0] pc;

    // PC update policy:
    //   - reset forces PC=0
    //   - when halt is asserted, PC stops updating (freezes at current value)
    always @(posedge clk) begin
        if (rst)
            pc <= {ADDR_W{1'b0}};
        else if (!halt)
            pc <= pc_next;
    end

    //==============================================================================
    // 3) Instruction fetch (instr_mem) + instruction fields
    //==============================================================================

    wire [INSTR_W-1:0] instr;

    // Instruction memory: synchronous/asynchronous depends on your instr_mem design
    instr_mem #(
        .ADDR_W (ADDR_W),
        .INSTR_W(INSTR_W),
        .DEPTH  (256)
    ) instr_mem_inst (
        .addr_in   (pc),
        .instr_out (instr)
    );

    // Decode fields (MIPS-like format)
    wire [5:0] opcode = instr[DATA_W-1:26];
    wire [4:0] rs     = instr[25:21];
    wire [4:0] rt     = instr[20:16];
    wire [4:0] rd     = instr[15:11];
    wire [4:0] shamt  = instr[10:6];
    wire [5:0] funct  = instr[5:0];
    wire [15:0] imm   = instr[15:0];

    // Immediate extension policy:
    //   - ANDI/ORI/LUI use zero-extend
    //   - others use sign-extend
    wire imm_is_zext =
        (opcode == OP_ANDI) ||
        (opcode == OP_ORI)  ||
        (opcode == OP_LUI);

    wire [DATA_W-1:0] imm_ext =
        imm_is_zext ? {16'b0, imm} : {{16{imm[15]}}, imm};

    // Shift instruction detection (uses shamt as operand)
    wire is_shift =
        (opcode == 6'b000000 && funct == FUNCT_SLL) ||
        (opcode == 6'b000000 && funct == FUNCT_SRL);

    //==============================================================================
    // 4) Control unit interface + control word breakdown
    //==============================================================================

    wire [CTRL_WORD_W-1:0] word;

    control_unit #(
        .CTRL_WORD_W(CTRL_WORD_W),
        .INSTR_W    (INSTR_W)
    ) control_unit_inst (
        .instr (instr),
        .word  (word),
        .halt  (halt)
    );

    // Control word mapping (MSB..LSB):
    //   [9] regWrite
    //   [8] regDst
    //   [7] aluSrc
    //   [6:4] aluControl
    //   [3] branch
    //   [2] memWrite
    //   [1] memtoReg
    //   [0] jump
    wire        regWrite         = word[9];
    wire        regDst           = word[8];
    wire        aluSrc           = word[7];
    wire [2:0]  aluControl       = word[6:4];
    wire        branch           = word[3];
    wire        memWrite         = word[2];
    wire        memtoReg         = word[1];
    wire        jump             = word[0];

    //==============================================================================
    // 5) Register bank (read + writeback selection)
    //==============================================================================

    wire [4:0] write_reg = (regDst) ? rd : rt;

    wire [DATA_W-1:0] rb_data_out1;
    wire [DATA_W-1:0] rb_data_out2;
    wire [DATA_W-1:0] rb_wdata;

    registers_bank rb_inst(
        .clk        (clk),
        .rst        (rst),
        .wr         (regWrite),
        .rd         (write_reg),
        .rs1        (rs),
        .rs2        (rt),
        .data_in    (rb_wdata),
        .data_out1  (rb_data_out1),
        .data_out2  (rb_data_out2)
    );

    //==============================================================================
    // 6) ALU operand selection + ALU execution
    //==============================================================================

    // ALU operand A:
    //   - for shifts: use shamt (zero-extended)
    //   - otherwise: use rs data
    wire [DATA_W-1:0] alu_a =
        (is_shift) ? {27'b0, shamt} : rb_data_out1;

    // ALU operand B:
    //   - aluSrc=1 selects imm_ext
    //   - aluSrc=0 selects rt data
    wire [DATA_W-1:0] alu_b =
        (aluSrc) ? imm_ext : rb_data_out2;

    wire [DATA_W-1:0] alu_out;
    wire              is_zero;

    alu #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .opcode  (aluControl),
        .in_a    (alu_a),
        .in_b    (alu_b),
        .out     (alu_out),
        .is_zero (is_zero)
    );

    //==============================================================================
    // 7) Data memory interface + writeback mux
    //==============================================================================

    // Tri-state data bus model:
    //   - store: CPU drives rb_data_out2 onto bus
    //   - load : CPU releases bus (Z), memory drives it
    wire [DATA_W-1:0] dm_data;
    assign dm_data =
        (memWrite) ? rb_data_out2 : {DATA_W{1'bz}};

    data_mem #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem_inst (
        .clk  (clk),
        .we   (memWrite),
        .addr (alu_out[ADDR_W-1:0]),
        .data (dm_data)
    );

    // Writeback:
    //   - memtoReg=1 selects dm_data (load)
    //   - memtoReg=0 selects alu_out
    assign rb_wdata = (memtoReg)? dm_data : alu_out;

    //==============================================================================
    // 8) PC next logic (pc_plus1 / branch / jump selection)
    //==============================================================================

    wire [ADDR_W-1:0] pc_plus1  = pc + 1;

    // Signed comparison for BLT (control logic, not ALU)
    wire signed_less;
    assign signed_less = ($signed(rb_data_out1) < $signed(rb_data_out2));

    // Branch handling:
    //   - is_bne is true for BNE opcode (000101)
    //   - is_blt is true for BLT opcode (000110)
    //   - is_beq is true for BEQ opcode (000100)
    //   - is_zero comes from ALU compare (typically subtraction result == 0)
    //   - For BEQ: take_branch when is_zero==1
    //   - For BNE: take_branch when is_zero==0
    //   - For BLT: take_branch when signed_less==1

    wire is_bne   = (opcode == 6'b000101);
    wire is_blt   = (opcode == 6'b000110);
    wire is_beq   = (opcode == 6'b000100);

    wire take_branch;
    
    assign take_branch =
        is_beq ?  ( is_zero)     :
        is_bne ?  (~is_zero)     :
        is_blt ?  ( signed_less) :
                  1'b0;
    
    // Branch target uses low ADDR_W bits of imm_ext
    wire [ADDR_W-1:0] pc_branch = pc_plus1 + imm_ext[ADDR_W-1:0];

    // Jump target uses low ADDR_W bits of instruction word
    wire [ADDR_W-1:0] pc_jump   = instr[ADDR_W-1:0];

    // Next PC selection priority:
    //   1) jump
    //   2) taken branch
    //   3) sequential pc_plus1
    wire [ADDR_W-1:0] pc_next   =
        (jump)        ? pc_jump   :
        (take_branch) ? pc_branch : pc_plus1;
        
endmodule