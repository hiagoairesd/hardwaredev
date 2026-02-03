module cpu_top(
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
    // 2) Architectural state (PC)
    //==============================================================================

    // PC update policy:
    //   - reset forces PC=0
    //   - when halt is asserted, PC stops updating (freezes at current value)

    always @(posedge clk) begin
        if(rst)
            pc <= {DATA_W{1'b0}};
        else if(PCWrite && !halt)
            pc <= pc_in;
    end

    //==============================================================================
    // 5) Memory
    //==============================================================================
    wire IorD;  // instruction or data fetch from memory selection
    wire [DATA_W-1:0] mem_out;       // memory output
    wire [DATA_W-1:0] mem_addr = (IorD)? alu_reg : pc; 
    // memory address selection: 1 for data, 0 for instruction
    wire [ADDR_W-1:0] mem_addr_word = mem_addr[ADDR_W+1:2];

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
    wire irWrite;

    always @(posedge clk) begin
        if (rst)
            instr <= {DATA_W{1'b0}};
        else if (irWrite)
            instr <= mem_out;
    end

    //------------------------------------------------------------------------------
    // Non-Architectural Instruction Register logic
    reg [DATA_W-1:0] mem_reg;   // data read from memory

    always @(posedge clk) begin
        if (rst)
            mem_reg <= {DATA_W{1'b0}};
        else if (IorD)
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

    // Immediate extension policy:
    //   - ANDI/ORI/LUI use zero-extend
    //   - others use sign-extend
    wire imm_is_zext =
        (opcode == OP_ANDI) ||
        (opcode == OP_ORI)  ||
        (opcode == OP_LUI);

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

    cu_fsm cu_fsm_inst (
        .opcode     (opcode),
        .funct      (funct),
        .regWrite   (regWrite),
        .regDst     (regDst),
        .aluSrc     (aluSrc),
        .aluControl (aluControl),
        .branch     (branch),
        .memWrite   (memWrite),
        .memToReg   (memtoReg),
        .jump       (jump)
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
        if (rst)
            rf_regA <= {DATA_W{1'b0}};
            rf_regB <= {DATA_W{1'b0}};
        else begin
            rf_regA <= rf_data_out1;
            rf_regB <= rf_data_out2;
        end
    end

    //==============================================================================
    // 6) ALU operand selection + ALU execution
    //==============================================================================
    wire aluSrcA;
    wire [1:0] aluSrcB;

    // ALU operand A:
    //   - aluSrcA=1 selects PC
    //   - aluSrcA=0 selects rs data
    wire [DATA_W-1:0] alu_a = (aluSrcA)? pc : rf_data_out1;

    // ALU operand B:
    //   - aluSrc=1 selects imm_ext
    //   - aluSrc=0 selects rt data
    wire [DATA_W-1:0] alu_b =
        (aluSrcB == 2'b00) ? rf_data_out2              :
        (aluSrcB == 2'b01) ? {{(DATA_W-3){1'b0}}, 3'd4} :
        (aluSrcB == 2'b10) ? imm_ext                   :
        (aluSrcB == 2'b11) ? (imm_ext << 2)            :
                             {DATA_W{1'b0}}; // default/fallback

    wire [DATA_W-1:0] alu_out;
    wire             is_zero;

    alu alu_inst (
        .opcode  (aluControl),
        .in_a    (alu_a),
        .in_b    (alu_b),
        .out     (alu_out),
        .is_zero (is_zero)
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
    
    //==============================================================================
    // 8) PC next logic (pc_plus4 / branch / jump selection)
    //==============================================================================
    // Halt signal from control unit; exported as output 'halted'
    wire halt;
    assign halted = halt;

    // Program counter is byte-indexed (DATA_W bits)
    reg  [DATA_W-1:0] pc;
    wire PCWrite;
    wire [DATA_W-1:0] pc_in;

    assign pc_in = alu_out; // Placeholder for PC next logic
endmodule