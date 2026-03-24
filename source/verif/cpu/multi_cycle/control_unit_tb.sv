module control_unit_tb();
    localparam INSTR_W = 32;
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_BLT   = 6'b000110;
    localparam OP_ORI   = 6'b001101;
    localparam OP_JUMP  = 6'b000010;
    localparam OP_HALT  = 6'b111111;

    localparam FNCT_ADD = 6'b100000;
    localparam FNCT_SLL = 6'b000000;

    reg clk, rst;
    reg [INSTR_W-1:0] instr;
    reg aluOut_is_zero, signed_less;

    wire PCEn, is_shift, imm_is_zext, memToReg, regDst, IorD, aluSrcA;
    wire [1:0] aluSrcB, PCSrc;
    wire IRWrite, memWrite, PCWrite, regWrite;
    wire [2:0] aluControl;
    wire halt;

`define CHECK_EQ(sig, exp) \
    if ((sig) !== (exp)) begin \
        $display("[FAIL] t=%0t %s=%b expected=%b", $time, `"sig`", (sig), (exp)); \
        $finish; \
    end

    function [31:0] enc_r;
        input [5:0] funct;
        begin
            enc_r = {OP_RTYPE, 5'd1, 5'd2, 5'd3, 5'd0, funct};
        end
    endfunction

    function [31:0] enc_i;
        input [5:0] opcode;
        begin
            enc_i = {opcode, 5'd1, 5'd2, 16'h0004};
        end
    endfunction

    function [31:0] enc_j;
        input [5:0] opcode;
        begin
            enc_j = {opcode, 26'h000003};
        end
    endfunction

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task expect_fetch;
        begin
            `CHECK_EQ(IRWrite, 1'b1);
            `CHECK_EQ(PCWrite, 1'b1);
            `CHECK_EQ(PCSrc, 2'b00);
            `CHECK_EQ(aluSrcA, 1'b0);
            `CHECK_EQ(aluSrcB, 2'b01);
            `CHECK_EQ(PCEn, 1'b1);
            `CHECK_EQ(memWrite, 1'b0);
            `CHECK_EQ(regWrite, 1'b0);
            `CHECK_EQ(halt, 1'b0);
        end
    endtask

    control_unit #(
        .INSTR_W(INSTR_W)
    ) DUT (
        .clk            (clk),
        .rst            (rst),
        .instr          (instr),
        .aluOut_is_zero (aluOut_is_zero),
        .signed_less    (signed_less),
        .PCEn           (PCEn),
        .is_shift       (is_shift),
        .imm_is_zext    (imm_is_zext),
        .memToReg       (memToReg),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);
    end

    initial begin
        rst            = 1'b1;
        instr          = 32'd0;
        aluOut_is_zero = 1'b0;
        signed_less    = 1'b0;

        step;
        expect_fetch();
        rst = 1'b0;

        instr = enc_i(OP_LW);
        step;
        `CHECK_EQ(aluSrcA, 1'b0);
        `CHECK_EQ(aluSrcB, 2'b11);
        step;
        `CHECK_EQ(aluSrcA, 1'b1);
        `CHECK_EQ(aluSrcB, 2'b10);
        `CHECK_EQ(aluControl, 3'b010);
        step;
        `CHECK_EQ(IorD, 1'b1);
        `CHECK_EQ(memWrite, 1'b0);
        step;
        `CHECK_EQ(regWrite, 1'b1);
        `CHECK_EQ(memToReg, 1'b1);
        `CHECK_EQ(regDst, 1'b0);
        step;
        expect_fetch();

        instr = enc_i(OP_SW);
        step;
        `CHECK_EQ(aluSrcA, 1'b0);
        `CHECK_EQ(aluSrcB, 2'b11);
        step;
        `CHECK_EQ(aluSrcA, 1'b1);
        `CHECK_EQ(aluSrcB, 2'b10);
        step;
        `CHECK_EQ(IorD, 1'b1);
        `CHECK_EQ(memWrite, 1'b1);
        `CHECK_EQ(regWrite, 1'b0);
        step;
        expect_fetch();

        instr = enc_r(FNCT_ADD);
        step;
        `CHECK_EQ(aluSrcA, 1'b0);
        `CHECK_EQ(aluSrcB, 2'b11);
        step;
        `CHECK_EQ(aluSrcA, 1'b1);
        `CHECK_EQ(aluSrcB, 2'b00);
        `CHECK_EQ(aluControl, 3'b010);
        `CHECK_EQ(is_shift, 1'b0);
        step;
        `CHECK_EQ(regWrite, 1'b1);
        `CHECK_EQ(regDst, 1'b1);
        `CHECK_EQ(memToReg, 1'b0);
        step;
        expect_fetch();

        instr = enc_r(FNCT_SLL);
        step;
        `CHECK_EQ(aluSrcA, 1'b0);
        `CHECK_EQ(aluSrcB, 2'b11);
        step;
        `CHECK_EQ(is_shift, 1'b1);
        `CHECK_EQ(aluControl, 3'b011);
        step;
        `CHECK_EQ(regWrite, 1'b1);
        step;
        expect_fetch();

        instr = enc_i(OP_ORI);
        step;
        `CHECK_EQ(aluSrcA, 1'b0);
        `CHECK_EQ(aluSrcB, 2'b11);
        step;
        `CHECK_EQ(imm_is_zext, 1'b1);
        `CHECK_EQ(aluControl, 3'b001);
        step;
        `CHECK_EQ(regWrite, 1'b1);
        `CHECK_EQ(regDst, 1'b0);
        step;
        expect_fetch();

        instr = enc_i(OP_BEQ);
        step;
        aluOut_is_zero = 1'b1;
        step;
        `CHECK_EQ(PCSrc, 2'b01);
        `CHECK_EQ(PCWrite, 1'b0);
        `CHECK_EQ(PCEn, 1'b1);
        step;
        expect_fetch();
        aluOut_is_zero = 1'b0;

        instr = enc_i(OP_BEQ);
        step;
        aluOut_is_zero = 1'b0;
        step;
        `CHECK_EQ(PCEn, 1'b0);
        step;
        expect_fetch();

        instr = enc_i(OP_BLT);
        step;
        signed_less = 1'b1;
        step;
        `CHECK_EQ(PCEn, 1'b1);
        step;
        expect_fetch();
        signed_less = 1'b0;

        instr = enc_j(OP_JUMP);
        step;
        step;
        `CHECK_EQ(PCSrc, 2'b10);
        `CHECK_EQ(PCWrite, 1'b1);
        `CHECK_EQ(PCEn, 1'b1);
        step;
        expect_fetch();

        instr = {OP_HALT, 26'd0};
        step;
        step;
        `CHECK_EQ(halt, 1'b1);
        `CHECK_EQ(regWrite, 1'b0);
        `CHECK_EQ(memWrite, 1'b0);
        `CHECK_EQ(PCWrite, 1'b0);
        step;
        `CHECK_EQ(halt, 1'b1);

        $display("[PASS] control_unit multi-cycle TB finalizado sem falhas");
        $finish;
    end

    initial begin
        #2000;
        $display("[FAIL] Timeout no testbench");
        $finish;
    end


endmodule