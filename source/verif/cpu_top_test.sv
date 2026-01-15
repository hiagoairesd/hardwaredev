`define ANSI_RED  "\033[31m"
`define ANSI_GRN  "\033[32m"
`define ANSI_BOLD "\033[1m"
`define ANSI_RST  "\033[0m"

module cpu_top_test();
    localparam ADDR_W = 8;
    localparam DATA_W = 32;

    reg clk;
    reg rst;

    integer test_id;
    integer max_cycles = 200;
    wire halted;
    
    cpu_top
    #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .halted(halted)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    bit trace, trace_w;
    initial begin
        trace_w = $test$plusargs("trace_w");
        trace   = $test$plusargs("trace") && !trace_w;
        if (trace) trace_w = 1'b1;
    end

    // Trace per cycle: PC + instr + opcode
    always @(posedge clk) begin
        if (!rst && trace) begin
            $display("t=%0t pc=%0d instr=%08h opcode=%02h",
                     $time, DUT.pc, DUT.instr, DUT.opcode);
        end
    end
    // Trace_w: Register + data
    always @(posedge clk) begin
        if(!rst && trace_w) begin
            // Writing in register 
            if(DUT.regWrite) begin
                $display("t=%0t | REGWRITE | R%0d <= %08h",
                         $time, DUT.write_reg, DUT.rb_wdata);
            end
            // Writing in memory(SW)
            if (DUT.memWrite) begin
              $display("t=%0t | MEMWRITE | mem[%0d] <= %08h",
                       $time, DUT.alu_out[ADDR_W-1:0], DUT.dm_data);
            end
            // Branch tomado
            if (DUT.take_branch) 
                $display("t=%0t | BRANCH taken -> pc_next=%0d",
                         $time, DUT.pc_next);
            // Jump
            if (DUT.jump)
                $display("t=%0t | JUMP -> pc_next=%0d",
                         $time, DUT.pc_next);
        end
    end
    initial begin
        $dumpfile("cpu_top.vcd");
        $dumpvars(0, cpu_top_test);
        $dumpvars(0, DUT.data_mem_inst.mem[0]);
        $dumpvars(0, DUT.data_mem_inst.mem[255]);
        $dumpvars(0, DUT.rb_inst.regs[1]);
        $dumpvars(0, DUT.rb_inst.regs[2]);
        $dumpvars(0, DUT.rb_inst.regs[3]);
        $dumpvars(0, DUT.rb_inst.regs[4]);
        $dumpvars(0, DUT.rb_inst.regs[5]);
        $dumpvars(0, DUT.rb_inst.regs[6]);
        $dumpvars(0, DUT.rb_inst.regs[7]);
        $dumpvars(0, DUT.rb_inst.regs[8]);
        $dumpvars(0, DUT.rb_inst.regs[9]);
        $dumpvars(0, DUT.rb_inst.regs[10]);
    end

    task automatic pick_test(input integer test_id);
        begin
            rst = 1'b1;
            #1;

            case(test_id)
                1:  $readmemh("../source/verif/assembly/regs.hex", DUT.instr_mem_inst.mem);
                2:  $readmemh("../source/verif/assembly/basic_swlw.hex", DUT.instr_mem_inst.mem);
                3:  $readmemh("../source/verif/assembly/border_swlw.hex", DUT.instr_mem_inst.mem);
                4:  $readmemh("../source/verif/assembly/rtype.hex", DUT.instr_mem_inst.mem);
                5:  $readmemh("../source/verif/assembly/jump.hex", DUT.instr_mem_inst.mem);
                6:  $readmemh("../source/verif/assembly/beq.hex", DUT.instr_mem_inst.mem);
                7:  $readmemh("../source/verif/assembly/andi.hex", DUT.instr_mem_inst.mem);
                8:  $readmemh("../source/verif/assembly/ori.hex", DUT.instr_mem_inst.mem);
                9:  $readmemh("../source/verif/assembly/lui.hex", DUT.instr_mem_inst.mem);
                10: $readmemh("../source/verif/assembly/sll.hex", DUT.instr_mem_inst.mem);
                11: $readmemh("../source/verif/assembly/srl.hex", DUT.instr_mem_inst.mem);
                12: $readmemh("../source/verif/assembly/bne.hex", DUT.instr_mem_inst.mem);
                default: $readmemh("../source/verif/assembly/integration.hex", DUT.instr_mem_inst.mem);
            endcase
        end
    endtask

    task automatic check_regs;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING REGS TESTS [1] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd2);
            check_reg(3, DUT.rb_inst.regs[3], 32'd3);
        end
    endtask
    
    task automatic check_basic_swlw;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BASIC SW/LW TESTS [2] ", `ANSI_RST});
            $display({`ANSI_BOLD, "------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd42);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd42);
            check_reg(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    task automatic check_border_swlw;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BORDER SW/LW TESTS [3] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-----", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1],           32'd32767);
            check_reg(2, DUT.rb_inst.regs[2],          -32'sd32768);
            check_reg(3, DUT.rb_inst.regs[3],          -32'sd1);
            check_mem(255, DUT.data_mem_inst.mem[255], -32'sd1);
            check_reg(4, DUT.rb_inst.regs[4],          -32'sd1);
            check_reg(5, DUT.rb_inst.regs[5],           32'd0);
        end
    endtask

    task automatic check_rtype;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING R-TYPE (ALU) TESTS [4] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-----", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd5);
            check_reg(2, DUT.rb_inst.regs[2], 32'd3);
            check_reg(3, DUT.rb_inst.regs[3], 32'd8);
            check_reg(4, DUT.rb_inst.regs[4], 32'd2);
            check_reg(5, DUT.rb_inst.regs[5], 32'd1);
            check_reg(6, DUT.rb_inst.regs[6], 32'd7);
            check_reg(7, DUT.rb_inst.regs[7], 32'd1);
            check_reg(8, DUT.rb_inst.regs[8], 32'd0);
        end
    endtask

    task automatic check_jump;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING JMP TESTS [5] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd0);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd4);
        end
    endtask

    task automatic check_beq;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BEQ TESTS [6] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd5);
            check_reg(2, DUT.rb_inst.regs[2], 32'd5);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd7);
            check_reg(5, DUT.rb_inst.regs[5], 32'd9);
            check_reg(6, DUT.rb_inst.regs[6], 32'd123);
        end
    endtask
    task automatic check_andi;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ANDi TESTS [7] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd305397760);
            check_reg(2, DUT.rb_inst.regs[2], 32'd305398015);
            check_reg(3, DUT.rb_inst.regs[3], 32'd15);
            check_reg(4, DUT.rb_inst.regs[4], 32'd240);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd15);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd240);
        end
    endtask
    task automatic check_ori;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ORi TESTS [8] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd0);
            check_reg(2, DUT.rb_inst.regs[2], 32'd1);
            check_reg(3, DUT.rb_inst.regs[3], 32'd241);
            check_reg(4, DUT.rb_inst.regs[4], 32'd3855);
            check_reg(5, DUT.rb_inst.regs[5], 32'd4095);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd241);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd4095);
        end
    endtask
    task automatic check_lui;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING LUI TESTS [9] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd305397760);
            check_reg(2, DUT.rb_inst.regs[2], 32'd0);
            check_reg(3, DUT.rb_inst.regs[3], 32'd4294901760);
            check_reg(4, DUT.rb_inst.regs[4], 32'd305441741);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd305397760);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd4294901760);
            check_mem(8, DUT.data_mem_inst.mem[8], 32'd305441741);
        end
    endtask
    task automatic check_sll;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SLL TESTS [10] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd16);
            check_reg(3, DUT.rb_inst.regs[3], 32'd32);
            check_reg(4, DUT.rb_inst.regs[4], 32'd240);
            check_reg(5, DUT.rb_inst.regs[5], 32'd61440);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd16);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd61440);
        end
    endtask
    task automatic check_srl;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SRL TESTS [11] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd2147483648);
            check_reg(2, DUT.rb_inst.regs[2], 32'd1073741824);
            check_reg(3, DUT.rb_inst.regs[3], 32'd240);
            check_reg(4, DUT.rb_inst.regs[4], 32'd15);
            check_reg(5, DUT.rb_inst.regs[5], 32'd0);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd1073741824);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd15);
        end
    endtask
    task automatic check_bne;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BNE TESTS [12] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd2);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd5);
            check_reg(5, DUT.rb_inst.regs[5], 32'd5);
            check_reg(6, DUT.rb_inst.regs[6], 32'd13107);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd13107);
        end
    endtask

    task automatic check_integration;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING INTEGRATION TESTS [default] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1,  DUT.rb_inst.regs[1],      32'd10);
            check_reg(2,  DUT.rb_inst.regs[2],      32'd15);
            check_reg(3,  DUT.rb_inst.regs[3],      32'd65536);
            check_reg(4,  DUT.rb_inst.regs[4],      32'd40);
            check_reg(5,  DUT.rb_inst.regs[5],      32'd20);
            check_reg(7,  DUT.rb_inst.regs[7],      32'd15);
            check_reg(8,  DUT.rb_inst.regs[8],      32'd31);
            check_reg(9,  DUT.rb_inst.regs[9],      32'd15);
            check_reg(10, DUT.rb_inst.regs[10],     32'd25);
            check_reg(11, DUT.rb_inst.regs[11],     32'd10);
            check_mem(0,  DUT.data_mem_inst.mem[0], 32'd25);
            check_reg(12, DUT.rb_inst.regs[12],     32'd25);
            check_reg(13, DUT.rb_inst.regs[13],     32'd1);
            check_reg(14, DUT.rb_inst.regs[14],     32'd0);
            check_mem(1,  DUT.data_mem_inst.mem[1], 32'd0);
        end
    endtask

    task automatic check_reg(
        input int addr,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got !== exp) begin
            $display({`ANSI_BOLD, `ANSI_RED, "\t\t TEST FAILED", `ANSI_RST});
            $display("\tAt time %0t", $time);
            $display("R%0d = %0d (0x%08h) | R%0d should be: %0d (0x%08h)",
                     addr, got, got, addr, exp, exp);
            $finish;
        end else begin
            $display("\tAt time %0t", $time);
            $display("R%0d = %0d (0x%08h) %sOK%s",
                     addr, got, got, {`ANSI_BOLD, `ANSI_GRN}, `ANSI_RST);
        end
    endtask

    task automatic check_mem(
        input int addr,
        input logic [31:0] got,
        input logic [31:0] exp);
        if (got !== exp) begin
            $display({`ANSI_BOLD, `ANSI_RED, "\t\t TEST FAILED", `ANSI_RST});
            $display("\tAt time %0t", $time);
            $display("MEM[%0d] = %0d (0x%08h) | MEM[%0d] should be: %0d (0x%08h)",
                     addr, got, got, addr, exp, exp);
            $finish;
        end else begin
            $display("\tAt time %0t", $time);
            $display("MEM[%0d] = %0d (0x%08h) %sOK%s",
                     addr, got, got, {`ANSI_BOLD, `ANSI_GRN}, `ANSI_RST);
        end
    endtask

    task automatic run_test(input integer test_id);
        integer i;
        begin
            rst = 1'b1;
            $display("\033[1;34m-> Reset asserted @%0t\033[0m", $time);

            #1;
            $display("\033[1;34m-> Loading program...");
            pick_test(test_id); //$readmemh...

            repeat (2) @(posedge clk);
            rst = 1'b0;
            $display("\033[1;34m-> Reset deasserted @%0t\033[0m", $time);
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk);
                if (DUT.halted == 1'b1) begin
                    $display("\033[1;34m-> HALT detected @%0t (PC=0x%08h)\033[0m", $time, DUT.pc);
                    i = max_cycles; // força sair do loop (workaround pro Icarus)
                end
            end
            if (DUT.halted != 1'b1) begin
                $fatal(1, "\033[1;31m\nTIMEOUT: HALT not reached after %0d max_cycles (PC=0x%08h) @%0t\033[0m",
                          max_cycles, DUT.pc, $time);
            end
            case(test_id)
                1: check_regs();
                2: check_basic_swlw();
                3: check_border_swlw();
                4: check_rtype();
                5: check_jump();
                6: check_beq();
                7: check_andi();
                8: check_ori();
                9: check_lui();
                10: check_sll();
                11: check_srl();
                12: check_bne();
                default: check_integration();
            endcase

            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, `ANSI_GRN, " TESTS PASSED ", `ANSI_RST});
            $display({`ANSI_BOLD, "-----------------------", `ANSI_RST});
        end
    endtask

    initial begin
        void'($value$plusargs("test=%d", test_id));
        run_test(test_id);
        $finish;
    end
endmodule