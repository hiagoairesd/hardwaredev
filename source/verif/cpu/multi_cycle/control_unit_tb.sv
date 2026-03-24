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

    task automatic check_eq_1;
        input [255:0] sig_name;
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
        input [255:0] sig_name;
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
        input [255:0] sig_name;
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
        input [255:0] title;
        begin
            $display("---------------------------------------------------------------------------------------------------------------------------------");
            $display("\t\t\t\t%0s", title);
        end
    endtask

    task print_case;
        input [255:0] title;
        begin
            $display("\t\t\t%0s", title);
        end
    endtask

    task print_ok;
        begin
            $display(
                "At time %0t: OK | PCEn=%b | IRWrite=%b | memWrite=%b | regWrite=%b | aluControl=%b | PCSrc=%b | is_shift=%b | imm_is_zext=%b | halt=%b",
                $time,
                PCEn,
                IRWrite,
                memWrite,
                regWrite,
                aluControl,
                PCSrc,
                is_shift,
                imm_is_zext,
                halt
            );
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

        print_section("RESET/FETCH");
        print_case("Reset -> FETCH");
        step;
        expect_fetch();
        print_ok();
        rst = 1'b0;

        print_section("LOAD/STORE OPERATIONS");
        print_case("LW (load)");
        instr = enc_i(OP_LW);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b0);
        check_eq_2("aluSrcB", aluSrcB, 2'b11);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b1);
        check_eq_2("aluSrcB", aluSrcB, 2'b10);
        check_eq_3("aluControl", aluControl, 3'b010);
        step;
        check_eq_1("IorD", IorD, 1'b1);
        check_eq_1("memWrite", memWrite, 1'b0);
        step;
        check_eq_1("regWrite", regWrite, 1'b1);
        check_eq_1("memToReg", memToReg, 1'b1);
        check_eq_1("regDst", regDst, 1'b0);
        step;
        expect_fetch();
        print_ok();

        print_case("SW (store)");
        instr = enc_i(OP_SW);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b0);
        check_eq_2("aluSrcB", aluSrcB, 2'b11);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b1);
        check_eq_2("aluSrcB", aluSrcB, 2'b10);
        step;
        check_eq_1("IorD", IorD, 1'b1);
        check_eq_1("memWrite", memWrite, 1'b1);
        check_eq_1("regWrite", regWrite, 1'b0);
        step;
        expect_fetch();
        print_ok();

        print_section("R-TYPE OPERATIONS");
        print_case("ADD (no shift)");
        instr = enc_r(FNCT_ADD);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b0);
        check_eq_2("aluSrcB", aluSrcB, 2'b11);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b1);
        check_eq_2("aluSrcB", aluSrcB, 2'b00);
        check_eq_3("aluControl", aluControl, 3'b010);
        check_eq_1("is_shift", is_shift, 1'b0);
        step;
        check_eq_1("regWrite", regWrite, 1'b1);
        check_eq_1("regDst", regDst, 1'b1);
        check_eq_1("memToReg", memToReg, 1'b0);
        step;
        expect_fetch();
        print_ok();

        print_section("SHIFT INSTRUCTIONS");
        print_case("SLL (is_shift=1)");
        instr = enc_r(FNCT_SLL);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b0);
        check_eq_2("aluSrcB", aluSrcB, 2'b11);
        step;
        check_eq_1("is_shift", is_shift, 1'b1);
        check_eq_3("aluControl", aluControl, 3'b011);
        step;
        check_eq_1("regWrite", regWrite, 1'b1);
        step;
        expect_fetch();
        print_ok();

        print_section("IMMEDIATE OPERATIONS");
        print_case("ORI (imm_is_zext=1)");
        instr = enc_i(OP_ORI);
        step;
        check_eq_1("aluSrcA", aluSrcA, 1'b0);
        check_eq_2("aluSrcB", aluSrcB, 2'b11);
        step;
        check_eq_1("imm_is_zext", imm_is_zext, 1'b1);
        check_eq_3("aluControl", aluControl, 3'b001);
        step;
        check_eq_1("regWrite", regWrite, 1'b1);
        check_eq_1("regDst", regDst, 1'b0);
        step;
        expect_fetch();
        print_ok();

        print_section("BRANCH INSTRUCTIONS");
        print_case("BEQ - take branch when zero=1");
        instr = enc_i(OP_BEQ);
        step;
        aluOut_is_zero = 1'b1;
        step;
        check_eq_2("PCSrc", PCSrc, 2'b01);
        check_eq_1("PCWrite", PCWrite, 1'b0);
        check_eq_1("PCEn", PCEn, 1'b1);
        step;
        expect_fetch();
        print_ok();
        aluOut_is_zero = 1'b0;

        print_case("BEQ - do not take branch when zero=0");
        instr = enc_i(OP_BEQ);
        step;
        aluOut_is_zero = 1'b0;
        step;
        check_eq_1("PCEn", PCEn, 1'b0);
        step;
        expect_fetch();
        print_ok();

        print_case("BLT - take branch when signed_less=1");
        instr = enc_i(OP_BLT);
        step;
        signed_less = 1'b1;
        step;
        check_eq_1("PCEn", PCEn, 1'b1);
        step;
        expect_fetch();
        print_ok();
        signed_less = 1'b0;

        print_section("JUMP INSTRUCTION");
        print_case("J (jump)");
        instr = enc_j(OP_JUMP);
        step;
        step;
        check_eq_2("PCSrc", PCSrc, 2'b10);
        check_eq_1("PCWrite", PCWrite, 1'b1);
        check_eq_1("PCEn", PCEn, 1'b1);
        step;
        expect_fetch();
        print_ok();

        print_section("HALT INSTRUCTION");
        print_case("HALT (halt=1)");
        instr = {OP_HALT, 26'd0};
        step;
        step;
        check_eq_1("halt", halt, 1'b1);
        check_eq_1("regWrite", regWrite, 1'b0);
        check_eq_1("memWrite", memWrite, 1'b0);
        check_eq_1("PCWrite", PCWrite, 1'b0);
        step;
        check_eq_1("halt", halt, 1'b1);
        print_ok();

        $display("\n\t\t\t\tALL TESTS PASSED");
        $finish;
    end

    initial begin
        #2000;
        $display("[FAIL] Timeout: simulation did not finish in time");
        $finish;
    end


endmodule