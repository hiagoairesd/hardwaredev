module cpu_top #(
    parameter ADDR_W = 8,
    parameter DATA_W = 32
)(
    input wire clk,
    input wire rst
);
    localparam INSTR_W = 32;
    localparam CTRL_WORD_W = 10;

    // Control Unit control signals
    wire [INSTR_W-1:0]     instr;
    wire [CTRL_WORD_W-1:0] word;
    reg  [ADDR_W-1:0]      pc;

    // PC Logic
    always @(posedge clk) begin
            if(rst)
                    pc <= {ADDR_W{1'b0}};
            else
                pc <= pc_next;
    end
    wire [ADDR_W-1:0] pc_plus1 = pc + 1;
    wire [ADDR_W-1:0] pc_branch = pc_plus1 + imm_sext[ADDR_W-1:0]; // branch target address (next + imm)
    wire take_branch            = branch & is_zero;
    wire [ADDR_W-1:0] pc_jump = instr[ADDR_W-1:0];
    wire [ADDR_W-1:0] pc_next = (jump)?         pc_jump :
                                ((take_branch)? pc_branch : pc_plus1);
    
    // Instruction fields
    wire [5:0] op     = instr[31:26];
    wire [4:0] rs     = instr[25:21];   // Source Register 1
    wire [4:0] rt     = instr[20:16];   // Source Register 2
    wire [4:0] rd     = instr[15:11];   // Destination Register 
    wire [4:0] shamt  = instr[10:6];
    wire [5:0] funct  = instr[5:0];

    wire [15:0] imm   = instr[15:0];
    wire [25:0] jmp   = instr[25:0];
    wire [31:0] imm_sext = {{16{imm[15]}}, imm};    // Imm sign-extend
    wire [31:0] imm_zext = {16'b0, imm};            // Imm zero-extend


    // Instruction Memory instantiation
    instr_mem
    #(
        .ADDR_W (ADDR_W),
        .INSTR_W(INSTR_W),
        .DEPTH  (256)
    ) instr_mem_inst (
        .addr_in  (pc),
        .instr_out(instr)
    );

    // Word control signals breakdown
    wire regWrite   = word[9];
    wire regDst     = word[8];
    wire aluSrc     = word[7];
    wire aluControl = word[6:4];
    wire branch     = word[3];
    wire memWrite   = word[2];
    wire memtoReg   = word[1];
    wire jump       = word[0];

    // Internal wires
    wire [4:0] write_reg   = (regDst)? rd : rt;                     // Destination Register  
    wire [31:0] alu_b      = (aluSrc)? imm_sext : rb_data_out2;     // ALU second operand
    wire [31:0] write_data = (memtoReg)? dm_data_out : alu_out;     // select data to write to Register Bank (from Data Memory or ALU)

    // Register Bank signals
    wire [4:0] rb_rd;
    wire [4:0] rb_rs1;
    wire [4:0] rb_rs2;
    wire [DATA_W-1:0] rb_data_in;
    wire [DATA_W-1:0] rb_data_out1;    // input A to ALU
    wire [DATA_W-1:0] rb_data_out2;    // input B to ALU

    // Control Unit instantiations
    registers_bank rb_inst(
        .clk        (clk),
        .rst        (rst),
        .wr         (regWrite),
        .rd         (rb_rd),
        .rs1        (rb_rs1),
        .rs2        (rb_rs2),
        .data_in    (rb_data_in),
        .data_out1  (rb_data_out1),
        .data_out2  (rb_data_out2)
    );

    // ALU signals
    wire [2:0] opcode;
    wire [DATA_W-1:0] out;
    wire is_zero;

    // ALU instantiation
    alu
    #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .opcode  (opcode),
        .in_a    (rb_data_out1),    // qual entrada deve ser? linha 66/67
        .in_b    (rb_data_out2),    // qual entrada deve ser? linha 66/67
        .out     (out),
        .is_zero (is_zero)
    );

    // Data Memory signals
    wire dm_wr;
    wire dm_rd;
    wire [ADDR_W-1:0] dm_addr;
    wire [DATA_W-1:0] dm_data;

    // Data Memory instantiation
    data_mem
    #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem_inst (
        .clk(clk),
        .wr(dm_wr),
        .rd(dm_rd),
        .addr(dm_addr),
        .data(dm_data)
    );

    // Control Unit instantiation
    control_unit 
    #(
        .CTRL_WORD_W(CTRL_WORD_W),
        .INSTR_W    (INSTR_W)
    ) control_unit_inst (
        .instr(instr),
        .word (word)
    );
endmodule