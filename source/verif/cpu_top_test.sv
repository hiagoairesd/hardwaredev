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
    integer cycles;
    
    cpu_top
    #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) DUT (
        .clk(clk),
        .rst(rst)
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
                1: begin    // Simple Registers Tests
                    $readmemh("../source/verif/assembly/regs.hex", DUT.instr_mem_inst.mem);
                    cycles= 9;
                end
                2: begin    // Basic SW/LW Tests
                    $readmemh("../source/verif/assembly/basic_swlw.hex", DUT.instr_mem_inst.mem);
                    cycles= 9;
                end
                3: begin    // Border SW/LW Tests
                    $readmemh("../source/verif/assembly/border_swlw.hex", DUT.instr_mem_inst.mem);
                    cycles= 15;
                end
                4: begin    // R-TYPE Tests (ALU Tests)
                    $readmemh("../source/verif/assembly/rtype.hex", DUT.instr_mem_inst.mem);
                    cycles= 14;
                end
                5: begin    // Jump Tests
                    $readmemh("../source/verif/assembly/jump.hex", DUT.instr_mem_inst.mem);
                    cycles= 11;
                end
                6: begin    // BEQ Tests
                    $readmemh("../source/verif/assembly/beq.hex", DUT.instr_mem_inst.mem);
                    cycles= 16;
                end
                default: begin  // Integration Tests
                    $readmemh("../source/verif/assembly/integration.hex", DUT.instr_mem_inst.mem);
                    cycles= 21;
                end
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

    task automatic check_integration;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING INTEGRATION TESTS [default] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------", `ANSI_RST});
            check_reg(1,  DUT.rb_inst.regs[1],      32'd1);
            check_reg(2,  DUT.rb_inst.regs[2],      32'd2);
            check_reg(3,  DUT.rb_inst.regs[3],      32'd3);
            check_reg(4,  DUT.rb_inst.regs[4],      32'd2);
            check_reg(5,  DUT.rb_inst.regs[5],      32'd2);
            check_reg(6,  DUT.rb_inst.regs[6],      32'd3);
            check_reg(7,  DUT.rb_inst.regs[7],      32'd1);
            check_reg(8,  DUT.rb_inst.regs[8],      32'd0);
            check_mem(0,  DUT.data_mem_inst.mem[0], 32'd3);
            check_reg(9,  DUT.rb_inst.regs[9],      32'd3);
            check_reg(10, DUT.rb_inst.regs[10],     32'd5);
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
        begin
            rst = 1'b1;
            $display("\033[1;34m-> Reset asserted @%0t\033[0m", $time);

            #1;
            $display("\033[1;34m-> Loading program...");
            pick_test(test_id); //$readmemh...

            repeat (2) @(posedge clk);
            rst = 1'b0;
            $display("\033[1;34m-> Reset deasserted @%0t\033[0m", $time);
            repeat (cycles) @(posedge clk);
            
            case(test_id)
                1: check_regs();
                2: check_basic_swlw();
                3: check_border_swlw();
                4: check_rtype();
                5: check_jump();
                6: check_beq();
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