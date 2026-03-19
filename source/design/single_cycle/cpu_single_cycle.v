//==============================================================================
// cpu_single_cycle.sv
//
// Module: cpu_single_cycle
// Type  : MIPS-like single-cycle CPU top (PC-indexed instruction memory)
//
// PURPOSE
//   - Connects instruction memory, control unit, register file, ALU, and data memory
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
//       * when memWrite=1, CPU drives dm_data with rf_data_out2 (store data)
//       * otherwise dm_data = Z (data_mem is expected to drive for loads)
//   - Shift instructions:
//       * ALU input A uses shamt (zero-extended) when instruction is shift
//       * ALU input B is selected by aluSrc (imm_ext vs rf_data_out2)
//
// DEBUG OBSERVABILITY
//   - Internal signals are named to be waveform-friendly:
//       pc, pc_next, instr, opcode, rs/rt/rd, imm_ext
//       regWrite, memWrite, memtoReg, jump, take_branch
//       wa3, rf_wdata, alu_out, is_zero, dm_data
//==============================================================================

module cpu_single_cycle #(
    parameter int ADDR_W = 8,
    parameter int DATA_W = 32
)(
    input  wire clk,
    input  wire rst,
    output wire halted
);
    //==============================================================================
    // 1) Local parameters 
    //==============================================================================
    
    localparam int INSTR_W     = 32;
    localparam int CTRL_WORD_W = 10;

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
    // 3) Instruction fields + immediate extension
    //==============================================================================
    wire [INSTR_W-1:0] instr;

    // Decode fields (MIPS-like format)
    wire [5:0] opcode = instr[DATA_W-1:26];
    wire [4:0] rs     = instr[25:21];
    wire [4:0] rt     = instr[20:16];
    wire [4:0] rd     = instr[15:11];
    wire [4:0] shamt  = instr[10:6];
    wire [5:0] funct  = instr[5:0];
    wire [15:0] imm   = instr[15:0];

    wire [DATA_W-1:0] imm_ext =
        imm_is_zext ? {16'b0, imm} : {{16{imm[15]}}, imm};

    //==============================================================================
    // 4) Instruction memory
    //==============================================================================

    instr_mem #(
        .ADDR_W (ADDR_W),
        .INSTR_W(INSTR_W),
        .DEPTH  (256)
    ) instr_mem_inst (
        .addr_in   (pc),
        .instr_out (instr)
    );

    //==============================================================================
    // 5) Control unit
    //==============================================================================

    wire [CTRL_WORD_W-1:0] word;
    wire       regWrite, regDst, aluSrc;
    wire [2:0] aluControl;
    wire       take_branch, memWrite, memtoReg, jump, is_shift, imm_is_zext;

    control_unit #(
        .INSTR_W     (INSTR_W)
    ) control_unit_inst (
        .opcode      (opcode),
        .funct       (funct),
        .aluControl  (aluControl),
        .regwrite    (regWrite),
        .regdst      (regDst),
        .alusrc      (aluSrc),
        .take_branch (take_branch),
        .memwrite    (memWrite),
        .memtoreg    (memtoReg),
        .jump        (jump),
        .is_shift    (is_shift),
        .imm_is_zext (imm_is_zext),
        .halt        (halt)
    );
    //==============================================================================
    // 6) Register file (read + writeback selection)
    //==============================================================================

    wire [4:0] wa3 = (regDst) ? rd : rt;

    wire [DATA_W-1:0] rf_data_out1;
    wire [DATA_W-1:0] rf_data_out2;
    wire [DATA_W-1:0] rf_wdata;

    register_file register_file (
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

    //==============================================================================
    // 7) ALU operand selection + ALU execution
    //==============================================================================

    // ALU operand A:
    //   - for shifts: use shamt (zero-extended)
    //   - otherwise: use rs data
    wire [DATA_W-1:0] alu_a =
        (is_shift) ? {27'b0, shamt} : rf_data_out1;

    // ALU operand B:
    //   - aluSrc=1 selects imm_ext
    //   - aluSrc=0 selects rt data
    wire [DATA_W-1:0] alu_b =
        (aluSrc) ? imm_ext : rf_data_out2;

    wire [DATA_W-1:0] alu_out;
    wire              is_zero;
    wire              signed_less;

    alu #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .aluControl  (aluControl),
        .in_a        (alu_a),
        .in_b        (alu_b),
        .out         (alu_out),
        .is_zero     (is_zero),
        .signed_less (signed_less)
    );

    //==============================================================================
    // 8) Data memory interface + writeback mux
    //==============================================================================

    // Tri-state data bus model:
    //   - store: CPU drives rf_data_out2 onto bus
    //   - load : CPU releases bus (Z), memory drives it
    wire [DATA_W-1:0] dm_data;
    assign dm_data =
        (memWrite) ? rf_data_out2 : {DATA_W{1'bz}};

    data_mem #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem_inst (
        .clk  (clk),
        .we   (memWrite),
        .addr (alu_out[ADDR_W-1:0]),
        .data (dm_data)
    );
    //==============================================================================
    // 9) PC next logic (pc_plus1 / jump selection)
    //==============================================================================

    // PC + 1 (sequential next instruction)
    wire [ADDR_W-1:0] pc_plus1  = pc + 1;

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