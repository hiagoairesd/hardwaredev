module cpu_top #(
    parameter ADDR_W = 8,
    parameter DATA_W = 32
)(
    input wire clk,
    input wire rst
);
    localparam INSTR_W = 32;
    localparam CTRL_WORD_W = 10;

    // Register Bank signals
    wire rb_wr;
    wire [1:0] rb_wraddr;
    wire [1:0] rb_rda1;
    wire [1:0] rb_rda2;
    wire [DATA_W-1:0] rb_data_in;
    wire [DATA_W-1:0] rb_data_out1;    // input A to ALU
    wire [DATA_W-1:0] rb_data_out2;    // input B to ALU

    // ALU signals
    wire [2:0] opcode;
    wire [DATA_W-1:0] out;
    wire is_zero;

    // Data Memory signals
    wire dm_wr;
    wire dm_rd;
    wire [ADDR_W-1:0] dm_addr;
    wire [DATA_W-1:0] dm_data;

    // Instruction Memory signals
    wire [ADDR_W-1:0] im_addr_in;
    wire [DATA_W-1:0] im_instr_out;

    // Control Unit signals
    wire [INSTR_W-1:0]      cu_instr;
    wire [CTRL_WORD_W-1:0]  cu_word;

    registers_bank rb_inst(
        .clk        (clk),
        .rst        (rst),
        .wr         (rb_wr),
        .wraddr     (rb_wraddr),
        .rda1       (rb_rda1),
        .rda2       (rb_rda2),
        .data_in    (rb_data_in),
        .data_out1  (rb_data_out1),
        .data_out2  (rb_data_out2)
    );

    alu
    #(
        .DATA_W(DATA_W)
    ) alu_inst (
        .opcode  (opcode),
        .in_a    (rb_data_out1),
        .in_b    (rb_data_out2),
        .out     (out),
        .is_zero (is_zero)
    );

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

    instr_mem
    #(
        .ADDR_W (ADDR_W),
        .INSTR_W(INSTR_W),
        .DEPTH  (256)
    ) instr_mem_inst (
        .addr_in  (im_addr_in),
        .instr_out(im_instr_out)
    );

    control_unit 
    #(
        .CTRL_WORD_W(CTRL_WORD_W),
        .INSTR_W    (INSTR_W)
    ) control_unit_inst (
        .instr(cu_instr),
        .word (cu_word)
    );
endmodule