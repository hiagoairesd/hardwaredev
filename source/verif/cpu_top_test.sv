`timescale 1ns/1ps
//==============================================================================
// cpu_top_test.sv
//
// Testbench for: cpu_top (MIPS-like single-cycle CPU)
//
// PURPOSE
//   - Loads a program into DUT instruction memory (readmemh)
//   - Applies reset, runs the CPU for up to max_cycles cycles
//   - Terminates when DUT raises halted==1 (HALT instruction observed by DUT)
//   - Checks architectural state (register file + data memory) at end
//
// ASSUMPTIONS / CONTRACT (IMPORTANT)
//   - Instruction memory is indexed by "PC word index" (PC unit = 1 instruction).
//   - Data memory is indexed by word index (addr unit = 1 position, not bytes).
//     Example: sw rt, 1(r0) writes data_mem[1].
//   - DUT exposes internal debug signals used by this TB:
//       DUT.pc, DUT.instr, DUT.opcode, DUT.pc_next
//       DUT.regWrite, DUT.write_reg, DUT.rb_wdata
//       DUT.memWrite, DUT.alu_out, DUT.dm_data
//       DUT.take_branch, DUT.jump
//   - HALT handling:
//       DUT asserts halted==1 when it fetches/decodes HALT (e.g., 32'hFC000000).
//       TB ends execution as soon as halted is observed (posedge clk polling).
//
// PLUSARGS
//   +test=<id>      : selects which program to load / which checker to run
//   +trace          : lightweight trace (PC/instr/opcode each cycle), implies trace_w
//   +trace_w        : detailed trace (REGWRITE/MEMWRITE/BRANCH/JUMP)
//
// TRACE OUTPUT FORMAT (when enabled)
//   - "t=... pc=... instr=... opcode=..."
//   - "t=... | REGWRITE | R<idx> <= <data>"
//   - "t=... | MEMWRITE | mem[<addr>] <= <data>"
//   - "t=... | BRANCH taken -> pc_next=<...>"
//   - "t=... | JUMP -> pc_next=<...>"
//   - "-> HALT detected @t (PC=...)"
//
// HOW TO DEBUG QUICKLY
//   - Timeout: program missing HALT or control-flow bug (branch/jump/PC update).
//   - Wrong MEMWRITE address: check ALU addr calc + immediate sign/zero-extend.
//   - Wrong branch decisions: check comparator policy (signed vs unsigned) and SLT.
//==============================================================================

`define ANSI_RED  "\033[31m"
`define ANSI_GRN  "\033[32m"
`define ANSI_BLU  "\033[34m"
`define ANSI_BOLD "\033[1m"
`define ANSI_RST  "\033[0m"

module cpu_top_test();

    //==============================================================================
    // 1) Parameters / Localparams / TB defaults
    //==============================================================================

    // Memory index width used only for formatting/printing addresses in the TB
    // (DUT may have its own internal width/behavior).
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;

    // Maximum number of cycles the TB will allow before declaring TIMEOUT.
    // This is a safety net to prevent infinite simulations if HALT is not reached.
    integer max_cycles = 500;

    //==============================================================================
    // 2) Signals (TB <-> DUT) + TB runtime config
    //==============================================================================

    // TB-driven clock/reset
    reg clk;
    reg rst;

    // Selected test id (from +test=<id>)
    integer test_id;

    // Trace controls (from +trace / +trace_w)
    bit trace, trace_w;

    // DUT-provided halt indication
    wire halted;

    //==============================================================================
    // 3) DUT instantiation
    //==============================================================================

    cpu_top #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) DUT (
        .clk    (clk),
        .rst    (rst),
        .halted (halted)
    );

    //==============================================================================
    // 4) Clock generation
    //==============================================================================

    // Free-running clock. All TB stimulus/checks are synchronized to posedge clk.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //==============================================================================
    // 5) Simulation config (VCD)
    //==============================================================================

    // Always dump waveforms for debug. If you prefer, guard with +dump.
    initial begin
        $dumpfile("cpu_top.vcd");
        $dumpvars(0, cpu_top_test);
    end

    //==============================================================================
    // 6) Plusargs / runtime configuration
    //==============================================================================

    // Parses run-time options. Kept separate from the main initial to centralize config.
    initial begin
        // trace modes:
        //   +trace_w : detailed (writes/branches/jumps)
        //   +trace   : lightweight (pc/instr/opcode) AND forces trace_w
        trace_w = $test$plusargs("trace_w");
        trace   = $test$plusargs("trace") && !trace_w;
        if (trace) trace_w = 1'b1;

        // test selection: +test=<id>
        void'($value$plusargs("test=%d", test_id));

        // OPTIONAL: allow overriding max_cycles via +cycles=<n>
        // void'($value$plusargs("cycles=%d", max_cycles));
    end

    //==============================================================================
    // 7) Monitors / Trace (passive observers only)
    //==============================================================================

    // Trace per cycle: PC + instr + opcode (lightweight)
    // Note: this is passive; it does not drive any DUT input.
    always @(posedge clk) begin
        if (!rst && trace) begin
            $display("t=%0t pc=%0d instr=%08h opcode=%02h",
                     $time, DUT.pc, DUT.instr, DUT.opcode);
        end
    end

    // Trace_w: commits and control-flow events (detailed)
    // Note: printed on posedge after DUT state updates for the cycle.
    always @(posedge clk) begin
        if (!rst && trace_w) begin
            // Architectural register writeback
            if (DUT.regWrite) begin
                $display("t=%0t | REGWRITE | R%0d <= %08h",
                         $time, DUT.write_reg, DUT.rb_wdata);
            end

            // Architectural memory write (store word)
            if (DUT.memWrite) begin
                $display("t=%0t | MEMWRITE | mem[%0d] <= %08h",
                         $time, DUT.alu_out[ADDR_W-1:0], DUT.dm_data);
            end

            // Control-flow decisions
            if (DUT.take_branch) begin
                $display("t=%0t | BRANCH taken -> pc_next=%0d",
                         $time, DUT.pc_next);
            end
            if (DUT.jump) begin
                $display("t=%0t | JUMP -> pc_next=%0d",
                         $time, DUT.pc_next);
            end
        end
    end

    //==============================================================================
    // 8) Program loading utilities
    //==============================================================================

    //------------------------------------------------------------------------------
    // task: pick_test(test_id)
    //
    // Loads the program associated with test_id into instruction memory using
    // $readmemh. This task performs ONLY loading, and does not sequence reset.
    //
    // Requirements:
    //   - Program files contain 32-bit hex words, one per line (MIPS-like encoding).
    //   - Index in file corresponds to instr_mem index (PC unit = 1 instruction).
    //------------------------------------------------------------------------------
    task automatic pick_test(input integer test_id);
        begin
            case(test_id)
                1:  $readmemh("../source/verif/assembly/regs.hex",               DUT.instr_mem_inst.mem);
                2:  $readmemh("../source/verif/assembly/basic_swlw.hex",         DUT.instr_mem_inst.mem);
                3:  $readmemh("../source/verif/assembly/border_swlw.hex",        DUT.instr_mem_inst.mem);
                4:  $readmemh("../source/verif/assembly/rtype.hex",              DUT.instr_mem_inst.mem);
                5:  $readmemh("../source/verif/assembly/jump.hex",               DUT.instr_mem_inst.mem);
                6:  $readmemh("../source/verif/assembly/beq.hex",                DUT.instr_mem_inst.mem);
                7:  $readmemh("../source/verif/assembly/andi.hex",               DUT.instr_mem_inst.mem);
                8:  $readmemh("../source/verif/assembly/ori.hex",                DUT.instr_mem_inst.mem);
                9:  $readmemh("../source/verif/assembly/lui.hex",                DUT.instr_mem_inst.mem);
                10: $readmemh("../source/verif/assembly/sll.hex",                DUT.instr_mem_inst.mem);
                11: $readmemh("../source/verif/assembly/srl.hex",                DUT.instr_mem_inst.mem);
                12: $readmemh("../source/verif/assembly/bne.hex",                DUT.instr_mem_inst.mem);
                13: $readmemh("../source/verif/assembly/blt.hex",                DUT.instr_mem_inst.mem);
                14: $readmemh("../source/verif/assembly/fibonacci.hex",          DUT.instr_mem_inst.mem);
                15: $readmemh("../source/verif/assembly/fibonacci_overflow.hex", DUT.instr_mem_inst.mem);
                default:
                    $readmemh("../source/verif/assembly/integration.hex",        DUT.instr_mem_inst.mem);
            endcase
        end
    endtask

    //==============================================================================
    // 9) Check helpers (generic)
    //==============================================================================

    //------------------------------------------------------------------------------
    // task: check_reg(addr, got, exp)
    //
    // Compares a register value to expected. On mismatch, prints a readable error
    // and terminates the simulation. On match, prints OK.
    //
    // Notes:
    //   - Uses !== for X/Z sensitivity (helps catch uninitialized/wrong drivers).
    //------------------------------------------------------------------------------
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

    //------------------------------------------------------------------------------
    // task: check_mem(addr, got, exp)
    //
    // Compares a data memory location to expected. On mismatch, prints a readable
    // error and terminates the simulation. On match, prints OK.
    //
    // Notes:
    //   - TB assumes word-indexed memory: mem[addr] matches store/load index unit.
    //------------------------------------------------------------------------------
    task automatic check_mem(
        input int addr,
        input logic [31:0] got,
        input logic [31:0] exp
    );
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

    //==============================================================================
    // 10) Test-specific checks (catalog grouped)
    //==============================================================================

    //------------------------------------------------------------------------------
    // check_regs()
    // Test goal:
    //   - Validates basic register writes for the regs program (test_id=1).
    // PASS criteria:
    //   - R1=1, R2=2, R3=3
    //------------------------------------------------------------------------------
    task automatic check_regs;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING REGS TESTS [1] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd2);
            check_reg(3, DUT.rb_inst.regs[3], 32'd3);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_basic_swlw()
    // Test goal:
    //   - Validates SW/LW basic path and addressing (test_id=2).
    // PASS criteria:
    //   - R1=42 stored at MEM[0], later loaded into R2=42
    //------------------------------------------------------------------------------
    task automatic check_basic_swlw;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BASIC SW/LW TESTS [2] ", `ANSI_RST});
            $display({`ANSI_BOLD, "--------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd42);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd42);
            check_reg(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_border_swlw()
    // Test goal:
    //   - Edge cases for immediates/sign extension and memory bounds (test_id=3).
    // PASS criteria:
    //   - Specific signed boundary values in registers and MEM[255].
    //------------------------------------------------------------------------------
    task automatic check_border_swlw;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BORDER SW/LW TESTS [3] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1],           32'd32767);
            check_reg(2, DUT.rb_inst.regs[2],          -32'sd32768);
            check_reg(3, DUT.rb_inst.regs[3],          -32'sd1);
            check_mem(255, DUT.data_mem_inst.mem[255], -32'sd1);
            check_reg(4, DUT.rb_inst.regs[4],          -32'sd1);
            check_reg(5, DUT.rb_inst.regs[5],           32'd0);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_rtype()
    // Test goal:
    //   - Validates core ALU R-type operations (test_id=4).
    // PASS criteria:
    //   - Expected values in R1..R8 after executing rtype.hex.
    //------------------------------------------------------------------------------
    task automatic check_rtype;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING R-TYPE (ALU) TESTS [4] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------", `ANSI_RST});
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

    //------------------------------------------------------------------------------
    // check_jump()
    // Test goal:
    //   - Validates jump control-flow updates (test_id=5).
    // PASS criteria:
    //   - Expected registers after jump test program.
    //------------------------------------------------------------------------------
    task automatic check_jump;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING JMP TESTS [5] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd0);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd4);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_beq()
    // Test goal:
    //   - Validates BEQ behavior (taken / not taken) and loop correctness (test_id=6).
    // PASS criteria:
    //   - Expected registers after beq program.
    //------------------------------------------------------------------------------
    task automatic check_beq;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BEQ TESTS [6] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd5);
            check_reg(2, DUT.rb_inst.regs[2], 32'd5);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd7);
            check_reg(5, DUT.rb_inst.regs[5], 32'd9);
            check_reg(6, DUT.rb_inst.regs[6], 32'd123);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_andi()
    // Test goal:
    //   - Validates ANDI zero-extension and bit masking (test_id=7).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_andi;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ANDi TESTS [7] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd305397760);
            check_reg(2, DUT.rb_inst.regs[2], 32'd305398015);
            check_reg(3, DUT.rb_inst.regs[3], 32'd15);
            check_reg(4, DUT.rb_inst.regs[4], 32'd240);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd15);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd240);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_ori()
    // Test goal:
    //   - Validates ORI zero-extension and bit assembly (test_id=8).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_ori;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ORi TESTS [8] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd0);
            check_reg(2, DUT.rb_inst.regs[2], 32'd1);
            check_reg(3, DUT.rb_inst.regs[3], 32'd241);
            check_reg(4, DUT.rb_inst.regs[4], 32'd3855);
            check_reg(5, DUT.rb_inst.regs[5], 32'd4095);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd241);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd4095);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_lui()
    // Test goal:
    //   - Validates LUI placement (upper 16 bits) and subsequent ops (test_id=9).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_lui;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING LUI TESTS [9] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd305397760);
            check_reg(2, DUT.rb_inst.regs[2], 32'd0);
            check_reg(3, DUT.rb_inst.regs[3], 32'd4294901760);
            check_reg(4, DUT.rb_inst.regs[4], 32'd305441741);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd305397760);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd4294901760);
            check_mem(8, DUT.data_mem_inst.mem[8], 32'd305441741);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_sll()
    // Test goal:
    //   - Validates SLL shifting and edge conditions (test_id=10).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_sll;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SLL TESTS [10] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd16);
            check_reg(3, DUT.rb_inst.regs[3], 32'd32);
            check_reg(4, DUT.rb_inst.regs[4], 32'd240);
            check_reg(5, DUT.rb_inst.regs[5], 32'd61440);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd16);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd61440);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_srl()
    // Test goal:
    //   - Validates SRL logical right shift and edge conditions (test_id=11).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_srl;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SRL TESTS [11] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd2147483648);
            check_reg(2, DUT.rb_inst.regs[2], 32'd1073741824);
            check_reg(3, DUT.rb_inst.regs[3], 32'd240);
            check_reg(4, DUT.rb_inst.regs[4], 32'd15);
            check_reg(5, DUT.rb_inst.regs[5], 32'd0);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd1073741824);
            check_mem(4, DUT.data_mem_inst.mem[4], 32'd15);
        end
    endtask

    //------------------------------------------------------------------------------
    // check_bne()
    // Test goal:
    //   - Validates BNE behavior (taken / not taken) (test_id=12).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_bne;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BNE TESTS [12] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd2);
            check_reg(3, DUT.rb_inst.regs[3], 32'd0);
            check_reg(4, DUT.rb_inst.regs[4], 32'd5);
            check_reg(5, DUT.rb_inst.regs[5], 32'd5);
            check_reg(6, DUT.rb_inst.regs[6], 32'd13107);
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd13107);
        end
    endtask
    //------------------------------------------------------------------------------
    // check_blt()
    // Test goal:
    //   - Validates BLT behavior (taken) (test_id=13).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic check_blt;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BLT TESTS [13] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_mem(0, DUT.data_mem_inst.mem[0], 32'd1);
            check_mem(1, DUT.data_mem_inst.mem[1], 32'd1);
            check_mem(2, DUT.data_mem_inst.mem[2], 32'd1);
        end
    endtask
    //------------------------------------------------------------------------------
    // check_fibonacci()
    // Test goal:
    //   - Validates a longer program with loops and multiple instructions (test_id=14).
    // PASS criteria:
    //   - Expected Fibonacci sequence values in registers and memory.
    //   - Final success flag set to 1, and fib(20)=4181 stored in MEM[31].
        task automatic check_fibonacci;
            begin
                $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
                $write({`ANSI_BOLD, " RUNNING FIBONACCI TESTS [14] ", `ANSI_RST});
                $display({`ANSI_BOLD, "---------------", `ANSI_RST});
                check_reg(0, DUT.rb_inst.regs[0],  32'h0000);
                check_reg(1, DUT.rb_inst.regs[1],  32'h0A18);
                check_reg(2, DUT.rb_inst.regs[2],  32'h1055);
                check_reg(3, DUT.rb_inst.regs[3],  32'h1055);
                check_reg(4, DUT.rb_inst.regs[4],  32'h0014);
                check_reg(5, DUT.rb_inst.regs[5],  32'h0014);
                check_reg(6, DUT.rb_inst.regs[6],  32'h0014);
                check_reg(7, DUT.rb_inst.regs[7],  32'h0001);
                check_mem(0,  DUT.data_mem_inst.mem[0],  32'h0000);
                check_mem(1,  DUT.data_mem_inst.mem[1],  32'h0001);
                check_mem(2,  DUT.data_mem_inst.mem[2],  32'h0001);
                check_mem(3,  DUT.data_mem_inst.mem[3],  32'h0002);
                check_mem(4,  DUT.data_mem_inst.mem[4],  32'h0003);
                check_mem(5,  DUT.data_mem_inst.mem[5],  32'h0005);
                check_mem(6,  DUT.data_mem_inst.mem[6],  32'h0008);
                check_mem(7,  DUT.data_mem_inst.mem[7],  32'h000D);
                check_mem(8,  DUT.data_mem_inst.mem[8],  32'h0015);
                check_mem(9,  DUT.data_mem_inst.mem[9],  32'h0022);
                check_mem(10, DUT.data_mem_inst.mem[10], 32'h0037);
                check_mem(11, DUT.data_mem_inst.mem[11], 32'h0059);
                check_mem(12, DUT.data_mem_inst.mem[12], 32'h0090);
                check_mem(13, DUT.data_mem_inst.mem[13], 32'h00E9);
                check_mem(14, DUT.data_mem_inst.mem[14], 32'h0179);
                check_mem(15, DUT.data_mem_inst.mem[15], 32'h0262);
                check_mem(16, DUT.data_mem_inst.mem[16], 32'h03DB);
                check_mem(17, DUT.data_mem_inst.mem[17], 32'h063D);
                check_mem(18, DUT.data_mem_inst.mem[18], 32'h0A18);
                check_mem(19, DUT.data_mem_inst.mem[19], 32'h1055);
                check_mem(30, DUT.data_mem_inst.mem[30], 32'h0001);
                $display({`ANSI_BLU, "   Success flag (should be 1)", `ANSI_RST});
                check_mem(31, DUT.data_mem_inst.mem[31], 32'h1055);
                $display({`ANSI_BLU, "   Stores final Fibonacci value (fib(20) = 4181)", `ANSI_RST});
            end
    endtask
    //------------------------------------------------------------------------------
    // check_fibonacci_overflow()
    // Test goal:
    //   - Validates behavior when Fibonacci sequence exceeds 32-bit limit (test_id=15).
    // PASS criteria:
    //   - Expected overflowed value in R1 and MEM[0] (fib(47) = 2971215073).
        task automatic check_fibonacci_overflow;
            begin
                check_reg(0, DUT.rb_inst.regs[0],  32'h00000000);
                check_reg(1, DUT.rb_inst.regs[1],  32'h43A53F82);
                check_reg(2, DUT.rb_inst.regs[2],  32'h6D73E55F);
                check_reg(3, DUT.rb_inst.regs[3],  32'hB11924E1);
                check_reg(4, DUT.rb_inst.regs[4],  32'h0000002F);
                check_reg(5, DUT.rb_inst.regs[5],  32'h00000031);
                check_reg(6, DUT.rb_inst.regs[6],  32'h0000002F);
                check_reg(7, DUT.rb_inst.regs[7],  32'h00000001);
                check_reg(8, DUT.rb_inst.regs[8],  32'h00000001);
                check_reg(9, DUT.rb_inst.regs[9],  32'h00000001);
                check_mem(0,  DUT.data_mem_inst.mem[0],  32'h00000000);
                check_mem(1,  DUT.data_mem_inst.mem[1],  32'h00000001);
                check_mem(2,  DUT.data_mem_inst.mem[2],  32'h00000001);
                check_mem(3,  DUT.data_mem_inst.mem[3],  32'h00000002);
                check_mem(4,  DUT.data_mem_inst.mem[4],  32'h00000003);
                check_mem(5,  DUT.data_mem_inst.mem[5],  32'h00000005);
                check_mem(6,  DUT.data_mem_inst.mem[6],  32'h00000008);
                check_mem(7,  DUT.data_mem_inst.mem[7],  32'h0000000D);
                check_mem(8,  DUT.data_mem_inst.mem[8],  32'h00000015);
                check_mem(9,  DUT.data_mem_inst.mem[9],  32'h00000022);
                check_mem(10, DUT.data_mem_inst.mem[10], 32'h00000037);
                check_mem(11, DUT.data_mem_inst.mem[11], 32'h00000059);
                check_mem(12, DUT.data_mem_inst.mem[12], 32'h00000090);
                check_mem(13, DUT.data_mem_inst.mem[13], 32'h000000E9);
                check_mem(14, DUT.data_mem_inst.mem[14], 32'h00000179);
                check_mem(15, DUT.data_mem_inst.mem[15], 32'h00000262);
                check_mem(16, DUT.data_mem_inst.mem[16], 32'h000003DB);
                check_mem(17, DUT.data_mem_inst.mem[17], 32'h0000063D);
                check_mem(18, DUT.data_mem_inst.mem[18], 32'h00000A18);
                check_mem(19, DUT.data_mem_inst.mem[19], 32'h00001055);
                check_mem(20, DUT.data_mem_inst.mem[20], 32'h00001A6D);
                check_mem(21, DUT.data_mem_inst.mem[21], 32'h00002AC2);
                check_mem(22, DUT.data_mem_inst.mem[22], 32'h0000452F);
                check_mem(23, DUT.data_mem_inst.mem[23], 32'h00006FF1);
                check_mem(24, DUT.data_mem_inst.mem[24], 32'h0000B520);
                check_mem(25, DUT.data_mem_inst.mem[25], 32'h00012511);
                check_mem(26, DUT.data_mem_inst.mem[26], 32'h0001DA31);
                check_mem(27, DUT.data_mem_inst.mem[27], 32'h0002FF42);
                check_mem(28, DUT.data_mem_inst.mem[28], 32'h0004D973);
                check_mem(29, DUT.data_mem_inst.mem[29], 32'h0007D8B5);
                check_mem(33, DUT.data_mem_inst.mem[33], 32'h0035C7E2);
                check_mem(34, DUT.data_mem_inst.mem[34], 32'h005704E7);
                check_mem(35, DUT.data_mem_inst.mem[35], 32'h008CCCC9);
                check_mem(36, DUT.data_mem_inst.mem[36], 32'h00E3D1B0);
                check_mem(37, DUT.data_mem_inst.mem[37], 32'h01709E79);
                check_mem(38, DUT.data_mem_inst.mem[38], 32'h02547029);
                check_mem(39, DUT.data_mem_inst.mem[39], 32'h03C50EA2);
                check_mem(40, DUT.data_mem_inst.mem[40], 32'h06197ECB);
                check_mem(41, DUT.data_mem_inst.mem[41], 32'h09DE8D6D);
                check_mem(42, DUT.data_mem_inst.mem[42], 32'h0FF80C38);
                check_mem(43, DUT.data_mem_inst.mem[43], 32'h19D699A5);
                check_mem(44, DUT.data_mem_inst.mem[44], 32'h29CEA5DD);
                check_mem(45, DUT.data_mem_inst.mem[45], 32'h43A53F82);
                check_mem(46, DUT.data_mem_inst.mem[46], 32'h6D73E55F);
                check_mem(30, DUT.data_mem_inst.mem[30], 32'h00000001);
                $display({`ANSI_BLU, "   Success flag (should be 1)", `ANSI_RST});
                check_mem(31, DUT.data_mem_inst.mem[31], 32'h6D73E55F);
                $display({`ANSI_BLU, "   Last valid Fibonacci value (fib(46) = 1836311903)", `ANSI_RST});
                check_mem(32, DUT.data_mem_inst.mem[32], 32'hB11924E1);
                $display({`ANSI_BLU, "   Overflow detected | value (fib(47) wrapped = 2971215073)", `ANSI_RST});
            end
        endtask
    //------------------------------------------------------------------------------
    // check_integration()
    // Test goal:
    //   - Validates multiple instructions working together (default test).
    // PASS criteria:
    //   - Expected final architectural state (selected regs + memory locations).
    //------------------------------------------------------------------------------
    task automatic check_integration;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING INTEGRATION TESTS [default] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
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

    //==============================================================================
    // 11) Test sequencer (stimulus + termination + checking)
    //==============================================================================

    //------------------------------------------------------------------------------
    // task: run_test(id)
    //
    // High-level test flow:
    //   1) Assert reset
    //   2) Load program (based on id)
    //   3) Deassert reset
    //   4) Run until HALT or timeout (max_cycles)
    //   5) Run the test-specific checker for id
    //
    // Failure modes:
    //   - TIMEOUT if halted is not observed within max_cycles
    //   - Checker failure if any reg/mem mismatch is detected
    //------------------------------------------------------------------------------
    task automatic run_test(input integer id);
        integer i;
        begin
            // 1) Reset asserted
            rst = 1'b1;
            $display("\033[1;34m-> Reset asserted @%0t\033[0m", $time);

            // 2) Load program while reset is asserted
            #1;
            $display("\033[1;34m-> Loading program...\033[0m");
            pick_test(id);

            // Keep reset asserted for a couple cycles (ensures DUT internal state clears)
            repeat (2) @(posedge clk);

            // 3) Reset deasserted
            rst = 1'b0;
            $display("\033[1;34m-> Reset deasserted @%0t\033[0m", $time);

            // 4) Run loop: stop at HALT or after max_cycles
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk);
                if (DUT.halted == 1'b1) begin
                    $display("\033[1;34m-> HALT detected @%0t (PC=0x%08h)\033[0m", $time, DUT.pc);
                    i = max_cycles; // Icarus workaround to break loop
                end
            end

            // Enforce termination condition
            if (DUT.halted != 1'b1) begin
                $fatal(1,
                       "\033[1;31m\nTIMEOUT: HALT not reached after %0d max_cycles (PC=0x%08h) @%0t\033[0m",
                       max_cycles, DUT.pc, $time);
            end

            // 5) Check results
            case (id)
                1:  check_regs();
                2:  check_basic_swlw();
                3:  check_border_swlw();
                4:  check_rtype();
                5:  check_jump();
                6:  check_beq();
                7:  check_andi();
                8:  check_ori();
                9:  check_lui();
                10: check_sll();
                11: check_srl();
                12: check_bne();
                13: check_blt();
                14: check_fibonacci();
                15: check_fibonacci_overflow();
                default: check_integration();
            endcase

            // Summary banner for PASS
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, `ANSI_GRN, " TESTS PASSED ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------------------------", `ANSI_RST});
        end
    endtask
    
    //==============================================================================
    // 12) Main (entry point)
    //==============================================================================

    // Entry point: runs selected test (from +test=<id>) and ends simulation.
    initial begin
        run_test(test_id);
        $finish;
    end
endmodule