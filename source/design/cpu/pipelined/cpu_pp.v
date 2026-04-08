module cpu_pp #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter DEPTH  = 256
)(
    input  wire clk,
    input  wire rst,
    output wire halt
);

//==============================================================================
// 1) PC Logic (Fetch stage)
//==============================================================================
    reg  [ADDR_W-1:0] F_PC;                     // Program counter is byte-indexed (ADDR_W bits)
    wire [ADDR_W-1:0] F_PCnext;                 // Next PC value after selection logic
    wire [ADDR_W-1:0] F_PCjump;                 // Jump target address for J-type instructions
    wire [ADDR_W-1:0] F_PCplus4 = F_PC + 4;     // F_PC + 4 for next sequential instruction

    assign F_PCjump   = {F_PC[ADDR_W-1:ADDR_W-4], D_addr, 2'b00};    // Jump target address for J-type instructions
    assign F_PCnext   =
        (D_jump)        ? F_PCjump   :
        (M_take_branch) ? M_PCbranch : F_PCplus4;

// PC update policy:
//   - reset forces F_PC=0
//   - when halt is asserted, F_PC stops updating (freezes at current value)
    always @(posedge clk) begin
        if (rst)
            F_PC <= {ADDR_W{1'b0}};
        else if (!halt)
            F_PC <= F_PCnext;
    end
//==============================================================================
// ) Decode Register
//==============================================================================
    reg [DATA_W-1:0] D_instr;
    reg [ADDR_W-1:0] D_PCplus4;

    always @(posedge clk) begin
        if(rst || D_jump) begin     // Flush the decode stage on reset or jump by clearing the instruction and PC+4
                                    // incurs a one-cycle bubble to prevent incorrect branch calculations
            D_instr   <= {DATA_W{1'b0}};
            D_PCplus4 <= {ADDR_W{1'b0}};
        end else begin
            D_instr   <= instr;
            D_PCplus4 <= F_PCplus4;
        end
    end

//==============================================================================
// ) Execute Register
//==============================================================================
    reg [ADDR_W-1:0] E_PCplus4;
    reg [DATA_W-1:0] E_imm_ext;
    reg [2:0]        E_aluControl;
    reg              E_regWrite, E_memtoReg, E_memWrite, E_aluSrc, E_regDst;
    reg              E_take_branch;

    always @(posedge clk) begin
        if(rst) begin
            E_regWrite    <= 1'b0;
            E_memtoReg    <= 1'b0;
            E_memWrite    <= 1'b0;
            E_aluControl  <= 3'b000;
            E_aluSrc      <= 1'b0;
            E_regDst      <= 1'b0;
            E_PCplus4     <= {ADDR_W{1'b0}};
            E_imm_ext     <= {DATA_W{1'b0}};
            E_take_branch <= 1'b0;
            E_rt          <= {5{1'b0}};
            E_rd          <= {5{1'b0}};
            E_aluA       <= {DATA_W{1'b0}};
            E_aluB       <= {DATA_W{1'b0}};
        end else begin
            E_regWrite    <= D_regWrite;
            E_memtoReg    <= D_memtoReg;
            E_memWrite    <= D_memWrite;
            E_aluControl  <= D_aluControl;
            E_aluSrc      <= D_aluSrc;
            E_regDst      <= D_regDst;
            E_PCplus4     <= D_PCplus4;
            E_imm_ext     <= imm_ext;
            E_take_branch <= D_take_branch;
            E_rt          <= D_rt;
            E_rd          <= D_rd;
        // ALU operand A:
        //   - for shifts: use shamt (zero-extended)
        //   - otherwise: use rs data
            E_aluA <= (is_shift) ? {27'b0, D_shamt} : rf_out1;
        // ALU operand B:
        //   - E_aluSrc=1 selects imm_ext
        //   - E_aluSrc=0 selects rt data
            E_aluB <= (E_aluSrc) ? imm_ext : rf_out2;
        end
    end
//==============================================================================
// ) Memory Register
//==============================================================================
    reg [ADDR_W-1:0] M_PCbranch;
    reg M_regWrite, M_memtoReg, M_memWrite, M_take_branch;
    reg [4:0] M_wa3;
    always @(posedge clk) begin
        if(rst) begin
            M_regWrite    <= 1'b0;
            M_memtoReg    <= 1'b0;
            M_memWrite    <= 1'b0;
            M_PCbranch    <= {ADDR_W{1'b0}};
            M_take_branch <= 1'b0;
            M_wa3         <= {5{1'b0}};
        end else begin
            M_regWrite    <= E_regWrite;
            M_memtoReg    <= E_memtoReg;
            M_memWrite    <= E_memWrite;
            M_PCbranch    <= E_PCplus4 + E_imm_ext[ADDR_W-1:0];
            M_take_branch <= E_take_branch;
            M_wa3         <= E_wa3;
        end
    end
//==============================================================================
// ) Writeback Register
//==============================================================================
    reg W_regWrite, W_memtoReg;
    reg [4:0] W_wa3;
    always @(posedge clk) begin
        if(rst) begin
            W_regWrite <= 1'b0;
            W_memtoReg <= 1'b0;
            W_wa3      <= {5{1'b0}};
        end else begin
            W_regWrite <= M_regWrite; 
            W_memtoReg <= M_memtoReg;
            W_wa3      <= M_wa3;
        end
    end 
//==============================================================================
// )
//==============================================================================
    wire [4:0] E_wa3 = (E_regDst) ? E_rd : E_rt;    // Register File write Address (A3)

    wire [DATA_W-1:0] rf_out1;     // Data from D_rs register
    wire [DATA_W-1:0] rf_out2;     // Data from D_rt register
    wire [DATA_W-1:0] rf_in;
    
    register_file #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .NREGS  (NREGS)
    ) register_file (
        .clk        (clk),
        .rst        (rst),
        .we3        (W_regWrite),
        .rd1        (D_rs),         //A1
        .rd2        (D_rt),         //A2   
        .wa3        (W_wa3),        //A3
        .data_in    (rf_in),
        .data_out1  (rf_out1),
        .data_out2  (rf_out2)
    );

// Writeback:
//   - memtoReg=1 selects dm_data (load)
//   - memtoReg=0 selects aluOut
    assign rf_in = (W_memtoReg)? dm_data : aluOut;

//==============================================================================
// )
//==============================================================================
    wire [DATA_W-1:0] instr;        // Instruction fetched from instruction memory
    intr_mem #(
        .ADDR_W  (ADDR_W),
        .INSTR_W (INSTR_W),
        .DEPTH   (DEPTH)
    ) instr_mem (
        .addr_in   (F_PC),
        .instr_out (instr)
    );

//==============================================================================
// )
//==============================================================================
// Tri-state data bus model:
//   - For store: CPU drives rf_out2 onto bus
//   - For load : CPU releases bus (Z), memory drives it
    wire [DATA_W-1:0] dm_data;
    assign dm_data =
        (M_memWrite) ? rf_out2 : {DATA_W{1'bz}};
    
    data_mem #(
        .ADDR_W(ADDR_W)
    ) data_mem (
        .clk  (clk),
        .we   (M_memWrite),
        .addr (aluOut),
        .data (dm_data)
    );
//==============================================================================
// ) Instruction fields + immediate extension
//==============================================================================
    wire [5:0]  D_opcode = D_instr[DATA_W-1:26];
    wire [4:0]  D_rs     = D_instr[25:21];
    wire [4:0]  D_rt     = D_instr[20:16];
    wire [4:0]  D_rd     = D_instr[15:11];
    wire [4:0]  D_shamt  = D_instr[10:6];
    wire [15:0] D_imm    = D_instr[15:0];
    wire [25:0] D_addr   = D_instr[25:0];

    wire [DATA_W-1:0] imm_ext =
        imm_is_zext ? {16'b0, D_imm} : {{16{D_imm[15]}}, D_imm};

//==============================================================================
// )
//==============================================================================


//==============================================================================
// )
//==============================================================================
// Control signals generated by control unit based on opcode and function
    wire       D_regWrite, D_regDst, D_aluSrc, D_memWrite, D_memtoReg, D_take_branch;
    wire [2:0] D_aluControl;
    wire       D_jump, is_shift, imm_is_zext;

    control_unit #(
        .INSTR_W        (INSTR_W)
    ) control_unit (
        .instr          (D_instr),          // Current instruction
        .aluOut_is_zero (is_zero),        // ALU result is zero flag
        .signed_less    (signed_less),    // ALU signed less flag
        .aluControl     (D_aluControl),   // ALU operation control
        .regWrite       (D_regWrite),     // Enable register write
        .regDst         (D_regDst),       // Select destination register (rd vs rt)
        .aluSrc         (D_aluSrc),       // Select ALU source B (imm vs reg)
        .take_branch    (D_take_branch),    // Branch condition met
        .memWrite       (D_memWrite),     // Enable data memory write
        .memtoReg       (D_memtoReg),     // Select writeback source (mem vs ALU)
        .jump           (D_jump),           // Jump instruction
        .is_shift       (is_shift),       // Shift operation flag
        .imm_is_zext    (imm_is_zext),    // Zero-extend immediate flag
        .halt           (halt)            // Halt signal
    );

//==============================================================================
// 6) ALU operand selection + ALU execution
//==============================================================================
    reg  [DATA_W-1:0] E_aluA, E_aluB;
    wire [DATA_W-1:0] aluOut;
    wire              is_zero;
    wire              signed_less;

    alu #(
        .DATA_W(DATA_W)
    ) alu (
        .aluControl (E_aluControl),
        .in_a       (E_aluA),
        .in_b       (E_aluB),
        .out        (aluOut),
        .is_zero    (is_zero),
        .signed_less(signed_less)
    );
endmodule