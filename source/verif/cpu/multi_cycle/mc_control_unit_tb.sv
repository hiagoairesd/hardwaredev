module mc_control_unit_tb();
    localparam INSTR_W = 32;
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_BLT   = 6'b000110;
    localparam OP_ORI   = 6'b001101;
    localparam OP_ANDI  = 6'b001100;
    localparam OP_ADDI  = 6'b001000;
    localparam OP_JUMP  = 6'b000010;
    localparam OP_HALT  = 6'b111111;

    localparam FNCT_ADD = 6'b100000;
    localparam FNCT_SUB = 6'b100010;
    localparam FNCT_AND = 6'b100100;
    localparam FNCT_OR  = 6'b100101;
    localparam FNCT_SLT = 6'b101010;
    localparam FNCT_SLL = 6'b000000;
    localparam FNCT_SRL = 6'b000010;

    reg clk, rst;
    reg [INSTR_W-1:0] instr;
    reg aluOut_is_zero, signed_less;

    wire PCEn, is_shift, imm_is_zext, memToReg, regDst, IorD, aluSrcA;
    wire [1:0] aluSrcB, PCSrc;
    wire IRWrite, memWrite, PCWrite, regWrite;
    wire [2:0] aluControl;
    wire halt;

    task automatic check_eq_1;
        input string sig_name;
        input logic actual;
        input logic expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] t=%0t %0s got=%b expected=%b", $time, sig_name, actual, expected);
                $finish;
            end
        end
    endtask

    task automatic check_eq_2;
        input string sig_name;
        input logic [1:0] actual;
        input logic [1:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] t=%0t %0s got=%b expected=%b", $time, sig_name, actual, expected);
                $finish;
            end
        end
    endtask

    task automatic check_eq_3;
        input string sig_name;
        input logic [2:0] actual;
        input logic [2:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] t=%0t %0s got=%b expected=%b", $time, sig_name, actual, expected);
                $finish;
            end
        end
    endtask

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

    task print_section;
        input string title;
        begin
            $display("---------------------------------------------------------------------------------------------------------------------------------");
            $display("\t\t\t\t%0s", title);
        end
    endtask

    task print_case;
        input string title;
        begin
            $display("\t\t\t%0s", title);
        end
    endtask

    task print_ok;
        begin
            $display(
                "At time %0t: PCEn=%b | IRWrite=%b | memWrite=%b | regWrite=%b | aluControl=%b | PCSrc=%b | is_shift=%b | imm_is_zext=%b | halt=%b | OK",
                $time, PCEn, IRWrite, memWrite, regWrite, aluControl, PCSrc, is_shift, imm_is_zext, halt);
        end
    endtask

    task expect_fetch;
        begin
            check_eq_1("IRWrite", IRWrite, 1'b1);
            check_eq_1("PCWrite", PCWrite, 1'b1);
            check_eq_2("PCSrc", PCSrc, 2'b00);
            check_eq_1("aluSrcA", aluSrcA, 1'b0);
            check_eq_2("aluSrcB", aluSrcB, 2'b01);
            check_eq_1("PCEn", PCEn, 1'b1);
            check_eq_1("memWrite", memWrite, 1'b0);
            check_eq_1("regWrite", regWrite, 1'b0);
            check_eq_1("halt", halt, 1'b0);
        end
    endtask

    mc_control_unit #(
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
        $dumpvars(0, mc_control_unit_tb);
    end

    // -----------------------------------------------------------------------
    // Shared helper: checks DECODE state (common to all instructions)
    // -----------------------------------------------------------------------
    task expect_decode;
        begin
            check_eq_1("aluSrcA", aluSrcA, 1'b0);
            check_eq_2("aluSrcB", aluSrcB, 2'b11);
        end
    endtask

    // -----------------------------------------------------------------------
    // Per-instruction test tasks
    // -----------------------------------------------------------------------
    task test_lw;
        begin
            print_case("LW (load)");
            instr = enc_i(OP_LW);
            step; expect_decode();                                          // DECODE
            step;                                                           // MEM_ADR
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b10);
            check_eq_3("aluControl",aluControl, 3'b010);
            step;                                                           // MEM_READ
            check_eq_1("IorD",      IorD,      1'b1);
            check_eq_1("memWrite",  memWrite,  1'b0);
            step;                                                           // MEM_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("memToReg",  memToReg,  1'b1);
            check_eq_1("regDst",    regDst,    1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_sw;
        begin
            print_case("SW (store)");
            instr = enc_i(OP_SW);
            step; expect_decode();                                          // DECODE
            step;                                                           // MEM_ADR
            check_eq_1("aluSrcA",  aluSrcA,  1'b1);
            check_eq_2("aluSrcB",  aluSrcB,  2'b10);
            step;                                                           // MEM_WRITE
            check_eq_1("IorD",     IorD,     1'b1);
            check_eq_1("memWrite", memWrite, 1'b1);
            check_eq_1("regWrite", regWrite, 1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_add;
        begin
            print_case("ADD (no shift)");
            instr = enc_r(FNCT_ADD);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b00);
            check_eq_3("aluControl",aluControl, 3'b010);
            check_eq_1("is_shift",  is_shift,  1'b0);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("regDst",    regDst,    1'b1);
            check_eq_1("memToReg",  memToReg,  1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_sub;
        begin
            print_case("SUB (no shift)");
            instr = enc_r(FNCT_SUB);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b00);
            check_eq_3("aluControl",aluControl, 3'b110);
            check_eq_1("is_shift",  is_shift,  1'b0);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("regDst",    regDst,    1'b1);
            check_eq_1("memToReg",  memToReg,  1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_and;
        begin
            print_case("AND (no shift)");
            instr = enc_r(FNCT_AND);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b00);
            check_eq_3("aluControl",aluControl, 3'b000);
            check_eq_1("is_shift",  is_shift,  1'b0);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("regDst",    regDst,    1'b1);
            check_eq_1("memToReg",  memToReg,  1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_or;
        begin
            print_case("OR (no shift)");
            instr = enc_r(FNCT_OR);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b00);
            check_eq_3("aluControl",aluControl, 3'b001);
            check_eq_1("is_shift",  is_shift,  1'b0);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("regDst",    regDst,    1'b1);
            check_eq_1("memToReg",  memToReg,  1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_slt;
        begin
            print_case("SLT (no shift)");
            instr = enc_r(FNCT_SLT);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("aluSrcA",   aluSrcA,   1'b1);
            check_eq_2("aluSrcB",   aluSrcB,   2'b00);
            check_eq_3("aluControl",aluControl, 3'b111);
            check_eq_1("is_shift",  is_shift,  1'b0);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            check_eq_1("regDst",    regDst,    1'b1);
            check_eq_1("memToReg",  memToReg,  1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_sll;
        begin
            print_case("SLL (is_shift=1)");
            instr = enc_r(FNCT_SLL);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("is_shift",  is_shift,  1'b1);
            check_eq_3("aluControl",aluControl, 3'b011);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_srl;
        begin
            print_case("SRL (is_shift=1)");
            instr = enc_r(FNCT_SRL);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE
            check_eq_1("is_shift",  is_shift,  1'b1);
            check_eq_3("aluControl",aluControl, 3'b100);
            step;                                                           // ALU_WRITEBACK
            check_eq_1("regWrite",  regWrite,  1'b1);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_ori;
        begin
            print_case("ORI (imm_is_zext=1)");
            instr = enc_i(OP_ORI);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE_IMM
            check_eq_1("imm_is_zext",imm_is_zext, 1'b1);
            check_eq_3("aluControl", aluControl,  3'b001);
            step;                                                           // IMM_WRITEBACK
            check_eq_1("regWrite",   regWrite,    1'b1);
            check_eq_1("regDst",     regDst,      1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_andi;
        begin
            print_case("ANDI (imm_is_zext=1)");
            instr = enc_i(OP_ANDI);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE_IMM
            check_eq_1("imm_is_zext",imm_is_zext, 1'b1);
            check_eq_3("aluControl", aluControl,  3'b000);
            step;                                                           // IMM_WRITEBACK
            check_eq_1("regWrite",   regWrite,    1'b1);
            check_eq_1("regDst",     regDst,      1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_addi;
        begin
            print_case("ADDI (imm_is_zext=0)");
            instr = enc_i(OP_ADDI);
            step; expect_decode();                                          // DECODE
            step;                                                           // EXECUTE_IMM
            check_eq_1("imm_is_zext",imm_is_zext, 1'b0);
            check_eq_3("aluControl", aluControl,  3'b010);
            step;                                                           // IMM_WRITEBACK
            check_eq_1("regWrite",   regWrite,    1'b1);
            check_eq_1("regDst",     regDst,      1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_beq_taken;
        begin
            print_case("BEQ - take branch when zero=1");
            instr = enc_i(OP_BEQ);
            step;                                                           // DECODE
            aluOut_is_zero = 1'b1;
            step;                                                           // BRANCH
            check_eq_2("PCSrc",  PCSrc,  2'b01);
            check_eq_1("PCWrite",PCWrite,1'b0);
            check_eq_1("PCEn",   PCEn,   1'b1);
            step; expect_fetch(); print_ok();                               // FETCH
            aluOut_is_zero = 1'b0;
        end
    endtask

    task test_beq_not_taken;
        begin
            print_case("BEQ - do not take branch when zero=0");
            instr = enc_i(OP_BEQ);
            step;                                                           // DECODE
            aluOut_is_zero = 1'b0;
            step;                                                           // BRANCH
            check_eq_1("PCEn", PCEn, 1'b0);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_blt_taken;
        begin
            print_case("BLT - take branch when signed_less=1");
            instr = enc_i(OP_BLT);
            step;                                                           // DECODE
            signed_less = 1'b1;
            step;                                                           // BRANCH
            check_eq_1("PCEn", PCEn, 1'b1);
            step; expect_fetch(); print_ok();                               // FETCH
            signed_less = 1'b0;
        end
    endtask

    task test_jump;
        begin
            print_case("J (jump)");
            instr = enc_j(OP_JUMP);
            step;                                                           // DECODE
            step;                                                           // JUMP
            check_eq_2("PCSrc",  PCSrc,  2'b10);
            check_eq_1("PCWrite",PCWrite,1'b1);
            check_eq_1("PCEn",   PCEn,   1'b1);
            step; expect_fetch(); print_ok();                               // FETCH
        end
    endtask

    task test_halt;
        begin
            print_case("HALT (halt=1)");
            instr = {OP_HALT, 26'd0};
            step;                                                           // DECODE
            step;                                                           // HALT
            check_eq_1("halt",     halt,    1'b1);
            check_eq_1("regWrite", regWrite,1'b0);
            check_eq_1("memWrite", memWrite,1'b0);
            check_eq_1("PCWrite",  PCWrite, 1'b0);
            step;                                                           // HALT (stays)
            check_eq_1("halt", halt, 1'b1);
            print_ok();
        end
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        rst            = 1'b1;
        instr          = 32'd0;
        aluOut_is_zero = 1'b0;
        signed_less    = 1'b0;

        print_section("RESET/FETCH");
        print_case("Reset -> FETCH");
        step; expect_fetch(); print_ok();
        rst = 1'b0;

        print_section("LOAD/STORE INSTRUCTIONS");
        test_lw();
        test_sw();

        print_section("R-TYPE INSTRUCTIONS");
        test_add();
        test_sub();
        test_and();
        test_or();
        test_slt();

        print_section("SHIFT OPERATIONS");
        test_sll();
        test_srl();

        print_section("IMMEDIATE OPERATIONS");
        test_ori();
        test_andi();
        test_addi();

        print_section("BRANCH INSTRUCTIONS");
        test_beq_taken();
        test_beq_not_taken();
        test_blt_taken();

        print_section("JUMP INSTRUCTION");
        test_jump();

        print_section("HALT INSTRUCTION");
        test_halt();

        $display("\n\t\t\t\tALL TESTS PASSED");
        $finish;
    end

    initial begin
        #2000;
        $display("[FAIL] Timeout: simulation did not finish in time");
        $finish;
    end


endmodule