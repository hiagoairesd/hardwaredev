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

    // PC Next logic
    wire [ADDR_W-1:0] pc_plus1  = pc + 1;
    wire [ADDR_W-1:0] pc_branch = pc_plus1 + imm_sext[ADDR_W-1:0]; // branch target address (next + imm)
    wire take_branch            = branch & is_zero;
    wire [ADDR_W-1:0] pc_jump   = instr[ADDR_W-1:0];
    wire [ADDR_W-1:0] pc_next   = (jump       )? pc_jump   :
                                  (take_branch)? pc_branch : pc_plus1;
    
    // Instruction fields
    wire [4:0] rs     = instr[25:21];   // Source Register 1
    wire [4:0] rt     = instr[20:16];   // Source Register 2
    wire [4:0] rd     = instr[15:11];   // Destination Register 

    wire [15:0] imm   = instr[15:0];                // Immediate value
    wire [31:0] imm_sext = {{16{imm[15]}}, imm};    // Imm sign-extend

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
    wire [31:0] rb_wdata   = (memtoReg)? dm_data : alu_out;         // select data to write to Register Bank (from Data Memory or ALU)

    // Register Bank signals
    wire [DATA_W-1:0] rb_data_out1;    // input A to ALU
    wire [DATA_W-1:0] rb_data_out2;    // input B to ALU

    // Register Bank instantiation
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

    // ALU signals
    wire [2:0] alu_opcode = aluControl;
    wire [DATA_W-1:0] alu_out;
    wire is_zero;

    // ALU instantiation
    alu
    #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .opcode  (alu_opcode),
        .in_a    (rb_data_out1),
        .in_b    (alu_b),
        .out     (alu_out),
        .is_zero (is_zero)
    );

    // Data Memory signals
    wire [DATA_W-1:0] dm_data;
    assign dm_data = (memWrite)? rb_data_out2 : {DATA_W{1'bz}}; // tri-state data bus

    // Data Memory instantiation
    data_mem
    #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem_inst (
        .clk(clk),
        .we(memWrite),
        .addr(alu_out[ADDR_W-1:0]),
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