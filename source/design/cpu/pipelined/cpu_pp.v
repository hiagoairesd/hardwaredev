module cpu_pp #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int DEPTH  = 256
)(
    input  wire clk,
    input  wire rst,
    output wire halt
);
    wire halt;
    assign halt = halt;
    reg [ADDR_W-1:0] pc;

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
// ) Decode Register
//==============================================================================
    wire D_regWrite, D_memtoReg, D_memWrite, D_branch;
    wire D_aluControl, D_aluSrc, D_regDst;
    always @(posedge clk) begin
        if(rst) begin
            {D_regWrite, D_memtoReg, D_memWrite, D_branch, D_aluControl, D_aluSrc, D_regDst} <= 9'b0;
        end else

    end
//==============================================================================
// ) Execute Register
//==============================================================================
    wire E_regWrite, E_memtoReg, E_memWrite, E_branch;
    wire E_aluControl, E_aluSrc, E_regDst;
    always @(posedge clk) begin
        if(rst) begin
            {E_regWrite, E_memtoReg, E_memWrite, E_branch, E_aluControl, E_aluSrc, E_regDst} <= 9'b0;
        end else

    end
//==============================================================================
// ) Memory Register
//==============================================================================
    wire M_regWrite, M_memtoReg, M_memWrite, M_branch;
    always @(posedge clk) begin
        if(rst) begin
            {M_regWrite, M_memtoReg, M_memWrite, M_branch} <= 4'b0;
        end

        else

    end
//==============================================================================
// ) Writeback Register
//==============================================================================
    wire W_regWrite, W_memtoReg;
    always @(posedge clk) begin
        if(rst) begin
            {W_regWrite, W_memtoReg} <= 2'b0;
        end

        else

    end


//==============================================================================
// )
//==============================================================================
    wire [4:0] wa3 = (regDst) ? rd : rt;

    wire [DATA_W-1:0] rf_data_out1;     // Data from rs register
    wire [DATA_W-1:0] rf_data_out2;     // Data from rt register
    wire [DATA_W-1:0] rf_wdata;
    
    register_file #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .NREGS  (NREGS)
    ) register_file (
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
//   - memtoReg=1 selects dm_data (load)
//   - memtoReg=0 selects alu_out
    assign rf_wdata = (memtoReg)? dm_data : alu_out;

//==============================================================================
// )
//==============================================================================

    intr_mem #(
        .ADDR_W  (ADDR_W),
        .INSTR_W (INSTR_W),
        .DEPTH   (DEPTH)
    ) instr_mem (
        .addr_in   (pc),
        .instr_out (instr)
    );

//==============================================================================
// )
//==============================================================================
// Tri-state data bus model:
//   - For store: CPU drives rf_data_out2 onto bus
//   - For load : CPU releases bus (Z), memory drives it
    wire [DATA_W-1:0] dm_data;
    assign dm_data =
        (memWrite) ? rf_data_out2 : {DATA_W{1'bz}};
    
    data_mem #(
        .ADDR_W(ADDR_W)
    ) data_mem (
        .clk  (clk),
        .we   (memWrite),
        .addr (alu_out),
        .data (dm_data)
    );
//==============================================================================
// ) Instruction fields + immediate extension
//==============================================================================
    reg [DATA_W-1:0] instr;       // Instruction register
    
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
// )
//==============================================================================


//==============================================================================
// )
//==============================================================================
// Control signals generated by control unit based on opcode and function
    wire       regWrite, regDst, aluSrc;
    wire [2:0] aluControl;
    wire       take_branch, memWrite, memtoReg, jump, is_shift, imm_is_zext;

    control_unit #(
        .INSTR_W        (INSTR_W)
    ) control_unit (
        .instr          (instr),          // Current instruction
        .aluOut_is_zero (is_zero),        // ALU result is zero flag
        .signed_less    (signed_less),    // ALU signed less flag
        .aluControl     (aluControl),     // ALU operation control
        .regWrite       (regWrite),       // Enable register write
        .regDst         (regDst),         // Select destination register (rd vs rt)
        .aluSrc         (aluSrc),         // Select ALU source B (imm vs reg)
        .take_branch    (take_branch),    // Branch condition met
        .memWrite       (memWrite),       // Enable data memory write
        .memtoReg       (memtoReg),       // Select writeback source (mem vs ALU)
        .jump           (jump),           // Jump instruction
        .is_shift       (is_shift),       // Shift operation flag
        .imm_is_zext    (imm_is_zext),    // Zero-extend immediate flag
        .halt           (halt)            // Halt signal
    );


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

endmodule