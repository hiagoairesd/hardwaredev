module cpu_mc #(
    parameter DATA_W = 32,
    parameter ADDR_W = 32,
    parameter MEM_DEPTH = 256
)(
    input wire clk,
    input wire rst,
    output wire halt
);
    // ANSI Color Codes
    `define ANSI_RED  "\033[31m"
    `define ANSI_BOLD "\033[1m"
    `define ANSI_RST  "\033[0m"

    localparam INSTR_LIMIT = MEM_DEPTH / 2;
//==============================================================================
// 1) PC Logic
//==============================================================================
    reg  [ADDR_W-1:0] pc;           // Program counter is byte-indexed (ADDR_W bits)
    wire [ADDR_W-1:0] pc_next;      // Next PC value after selection logic
    wire [ADDR_W-1:0] PCJump;       // Jump target address for J-type instructions

    assign PCJump  = {pc[ADDR_W-1:ADDR_W-4], addr, 2'b00};    // Jump target address for J-type instructions
    assign pc_next = 
        (PCSrc == 2'b00) ? alu_out :   
        (PCSrc == 2'b01) ? alu_reg :
        (PCSrc == 2'b10) ? PCJump  : alu_out;
//==============================================================================
// 2) Memory
//==============================================================================
    wire [DATA_W-1:0] mem_out;
    wire [ADDR_W-1:0] mem_addr = (IorD)? alu_reg : pc;      // memory address selection: 1 for data, 0 for instruction
    wire [ADDR_W-1:0] mem_addr_word = {{2{1'b0}}, mem_addr[ADDR_W-1:2]}; // word-aligned address
    wire [DATA_W-1:0] mem_data_in = rf_regB;

    // Enforce that the CPU does not write to the instruction memory region at runtime.
    // Detect and terminate immediately (combinational), before any memory write can be committed.
    wire              illegal_mem_write = !rst && memWrite && (mem_addr_word < INSTR_LIMIT);

    memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH(MEM_DEPTH)
    ) memory (
        .clk        (clk),
        .we         (memWrite && !illegal_mem_write),
        .addr       (mem_addr_word),
        .data_in    (mem_data_in),
        .data_out   (mem_out)
    );
    // ---------------------------------------------------------
    // 1. MEMORY INITIALIZATION CHECK (Startup)
    // ---------------------------------------------------------
    always @(negedge rst) begin
        // Check that data region (INSTR_LIMIT..MEM_DEPTH-1) remains zero after program load.
        // Any non-zero entry indicates instruction-file overflow into data memory.
        for (integer i = INSTR_LIMIT; i < MEM_DEPTH; i = i + 1) begin
            if (memory.mem[i] !== 32'h0) begin
                $fatal(1, $sformatf(
                    {`ANSI_BOLD, `ANSI_RED,
                     "\n[CPU][MEMORY LOAD ERROR] HEX initialization overflow into data region. \n\t\tWord index=%0d | Instruction Limit=0..%0d.",
                     `ANSI_RST},
                    i, INSTR_LIMIT-1
                ));
            end
        end
    end

    // ---------------------------------------------------------
    // 2. MEMORY ACCESS VIOLATION CHECK (Runtime)
    // ---------------------------------------------------------
    // Enforce that the CPU does not write to the instruction memory region at runtime.
    // Detect and terminate immediately (combinational), before any memory write can be committed.
    always @(*) begin
        if (illegal_mem_write) begin
            $fatal(1, $sformatf(
                {`ANSI_BOLD, `ANSI_RED,
                 "\n[CPU][MEMORY ACCESS VIOLATION] Illegal write to instruction region. \n\tAddress = %0d | Data = 0x%0h | Data Limit = %0d..%0d.",
                 `ANSI_RST},
                mem_addr_word, mem_data_in, INSTR_LIMIT, MEM_DEPTH-1
            ));
        end
    end
//==============================================================================
// 3) Instruction fields + immediate extension
//==============================================================================
    wire [5:0] opcode  = instr[DATA_W-1:26];
    wire [4:0]  rs     = instr[25:21];
    wire [4:0]  rt     = instr[20:16];
    wire [4:0]  rd     = instr[15:11];
    wire [4:0]  shamt  = instr[10:6];
    wire [15:0] imm    = instr[15:0];
    wire [25:0] addr   = instr[25:0];

    wire [DATA_W-1:0] imm_ext =
        imm_is_zext ? {16'b0, imm} : {{16{imm[15]}}, imm};

//==============================================================================
// 4) Control unit
//==============================================================================
    wire       regWrite, regDst, aluSrc;
    wire [2:0] aluControl;
    wire       memWrite, memtoReg, PCEn, is_shift, imm_is_zext, IorD, aluSrcA;
    wire [1:0] aluSrcB, PCSrc;
    wire       IRWrite, PCWrite;

    control_unit #(
        .INSTR_W(DATA_W)
    ) control_unit (
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
    assign rf_wdata = (memtoReg)? mem_reg : alu_reg;

//==============================================================================
// 6) ALU operand selection + ALU execution
//==============================================================================
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
        (aluSrcB == 2'b00) ? rf_regB                    :
        (aluSrcB == 2'b01) ? {{(DATA_W-3){1'b0}}, 3'd4} :
        (aluSrcB == 2'b10) ? imm_ext                    : 
                             (imm_ext << 2); // (aluSrcB == 2'b11)

    wire [DATA_W-1:0] alu_out;
    wire              is_zero;
    wire              signed_less;

    alu #(
        .DATA_W(DATA_W)
    ) alu (
        .aluControl (aluControl),
        .in_a       (alu_a),
        .in_b       (alu_b),
        .out        (alu_out),
        .is_zero    (is_zero),
        .signed_less(signed_less)
    );

//==============================================================================
// 7) State registers for multi-cycle operation
//==============================================================================
    reg [DATA_W-1:0] alu_reg;     // ALU output register to hold intermediate results across cycles
    reg [DATA_W-1:0] instr;       // Instruction register
    reg [DATA_W-1:0] mem_reg;     // data read from memory
    reg [DATA_W-1:0] rf_regA;     // register file output A (rs)
    reg [DATA_W-1:0] rf_regB;     // register file output B (rt)

    always @(posedge clk) begin
        if (rst) begin
            pc      <= {ADDR_W{1'b0}};
            instr   <= {DATA_W{1'b0}};
            alu_reg <= {DATA_W{1'b0}};
            mem_reg <= {DATA_W{1'b0}};
            rf_regA <= {DATA_W{1'b0}};
            rf_regB <= {DATA_W{1'b0}};
        end else begin
            if(!halt) begin
                if (PCEn) begin
                    pc    <= pc_next;
                end
                if (IRWrite) begin
                    instr <= mem_out;
                end
                alu_reg <= alu_out;
                mem_reg <= mem_out;
                rf_regA <= rf_data_out1;
                rf_regB <= rf_data_out2;
            end
        end
    end
endmodule
    