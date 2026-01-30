module cpu_top(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
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
    
    reg [ADDR_W-1:0] pc;

    always @(posedge clk) begin
        if(rst)
            pc <= {ADDR_W{1'b0}};
    end

    //==============================================================================
    // 5) Memory
    //==============================================================================
    wire IorD;  // instruction or data fetch from memory selection
    wire [DATA_W-1:0] mem_out;                        // memory output
    wire [ADDR_W-1:0] mem_addr = (IorD)? aluOut : pc; // memory address selection
    
    wire [DATA_W-1:0] mem_data_in;
    assign mem_data_in =
        (memWrite) ? rf_data_out2 : {DATA_W{1'bz}};

    memory #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W)
    ) memory_inst (
        .clk(clk),
        .we(memWrite),
        .addr(mem_addr),
        .data_in(mem_data_in),
        .data_out(mem_out)
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
    reg [DATA_W-1:0] mem_data_out;   // data read from memory

    always @(posedge clk) begin
        if (rst)
            mem_data_out <= {DATA_W{1'b0}};
        else if (IorD)
            mem_data_out <= mem_out;
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

    cu_fsm #(
        .CTRL_WORD_W(CTRL_WORD_W),
    ) cu_fsm_inst (
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
        .wa3        (wa3),
        .rd1        (rs),
        .rd2        (rt),
        .data_in    (rf_wdata),
        .data_out1  (rf_data_out1),
        .data_out2  (rf_data_out2)
    );

    // Writeback:
    //   - memtoReg=1 selects mem_data_out (load)
    //   - memtoReg=0 selects aluOut
    assign rf_wdata = (memtoReg)? mem_data_out : aluOut;

    //------------------------------------------------------------------------------
    // Non-Architectural Register File output register logic

    reg [DATA_W-1:0] rf_out;

    always @(posedge clk) begin
        if (rst)
            rf_out <= {DATA_W{1'b0}};
        else
            rf_out <= rf_data_out1;
    end

    //==============================================================================
    // 6) ALU operand selection + ALU execution
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

    wire [DATA_W-1:0] aluOut;
    wire              is_zero;

    alu #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .opcode  (aluControl),
        .in_a    (alu_a),
        .in_b    (alu_b),
        .out     (aluOut),
        .is_zero (is_zero)
    );

    //------------------------------------------------------------------------------
    // Non-Architectural ALU output register logic
    reg [DATA_W-1:0] aluResult;

    always @(posedge clk) begin
        if (rst)
            aluResult <= {DATA_W{1'b0}};
        else
            aluResult <= aluOut;
    end
    
    //==============================================================================
    // 8) PC next logic (pc_plus1 / branch / jump selection)
    //==============================================================================


    

endmodule