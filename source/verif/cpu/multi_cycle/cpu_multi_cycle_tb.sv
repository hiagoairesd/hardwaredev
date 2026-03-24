`timescale 1ns/1ps
//==============================================================================
// cpu_multi_cycle.sv
//
// Testbench for: cpu_multi_cycle (MIPS-like multi-cycle CPU)
//
// PURPOSE
//   - Loads a program into DUT instruction memory (readmemh)
//   - Applies reset, runs the CPU for up to max_cycles cycles
//   - Terminates when DUT raises halt==1 (HALT instruction observed by DUT)
//   - Checks architectural state (register file + data memory) at end
//
// ASSUMPTIONS / CONTRACT (IMPORTANT)
//   - Instruction memory is indexed by "PC word index" (PC unit = 1 instruction).
//   - Data memory is indexed by word index (addr unit = 1 position, not bytes).
//     Example: sw rt, 1(r0) writes data_mem[1].
//   - DUT exposes internal debug signals used by this TB:
//       DUT.pc, DUT.instr, DUT.opcode, DUT.pc_next
//       DUT.regWrite, DUT.wa3, DUT.rf_wdata
//       DUT.memWrite, DUT.alu_out, DUT.mem_data_in
//       DUT.take_branch, DUT.jump
//   - HALT handling:
//       DUT asserts halt==1 when it fetches/decodes HALT (e.g., 32'hFC000000).
//       TB ends execution as soon as halt is observed (posedge clk polling).
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

module cpu_multi_cycle_tb();

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

    // Trace controls (from +trace / +trace_w / +trace_m)
    bit trace, trace_w, trace_m;

    // DUT-provided halt indication
    wire halt;

    //==============================================================================
    // 3) DUT instantiation
    //==============================================================================

    cpu_multi_cycle #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W)
    ) DUT (
        .clk    (clk),
        .rst    (rst),
        .halt (halt)
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
        $dumpfile("cpu_multi_cycle.vcd");
        $dumpvars(0, cpu_multi_cycle_tb);
    end

    //==============================================================================
    // 6) Plusargs / runtime configuration
    //==============================================================================

    // Parses run-time options. Kept separate from the main initial to centralize config.
    initial begin
        // trace modes:
        //   +trace_w : detailed (writes/branches/jumps)
        //   +trace   : lightweight (pc/instr/opcode) AND forces trace_w
        //   +trace_m : microarchitectural (internal signals like reg A/B, ALU out)
        trace_w = $test$plusargs("trace_w");
        trace   = $test$plusargs("trace") && !trace_w;
        trace_m = $test$plusargs("trace_m");
        if (trace) trace_w = 1'b1;

        // test selection: +test=<id>
        void'($value$plusargs("test=%d", test_id));

        // OPTIONAL: allow overriding max_cycles via +cycles=<n>
        // void'($value$plusargs("cycles=%d", max_cycles));
    end

    //==============================================================================
    // 7) Monitors / Trace (passive observers only)
    //==============================================================================
    // Single synchronized debug block
    always @(posedge clk) begin
        // Tiny delay (#1) to ensure all internal signals to stabilize after the clock edge
        #1;
        if (!rst) begin
            // 1. Primary Trace (Time, PC, Instr, State)
            if (trace) begin
                $display("t=%0t [PC=%0d] [Instr=%08h] [State=%s]",
                         $time, DUT.pc, DUT.instr, get_state_name(DUT.control_unit.state));
            end
            // 2. Internal Microarchitecture Trace (A, B, ALUOut)
            if (trace_m) begin
                $display("   [INTERNAL] A=%h | B=%h | ALUOut=%h | State=%0d", 
                         DUT.rf_regA, DUT.rf_regB, DUT.alu_reg, DUT.control_unit.state);
            end
            // 3. Writeback/Commit Trace (Events)
            if (trace_w) begin
                // Register Write
                if (DUT.regWrite && (DUT.control_unit.state == 4'd4 || DUT.control_unit.state == 4'd7 || DUT.control_unit.state == 4'd9)) begin
                    $display("   >>> REGWRITE | R%0d <= %08h (Committed)", DUT.wa3, DUT.rf_wdata);
                end
                // Memory Write
                if (DUT.memWrite && DUT.control_unit.state == 4'd5) begin
                    $display("   >>> MEMWRITE | mem[%0d] <= %08h", DUT.alu_out, DUT.mem_data_in);
                end
                // Jump / Branch Events
                if (DUT.control_unit.state == 4'd10) begin
                    $display("   >>> JUMP -> Target: %0d", DUT.pc_next);
                end
                if (DUT.control_unit.state == 4'd8 && DUT.control_unit.take_branch) begin
                    $display("   >>> BRANCH Taken -> Target: %0d", DUT.pc_next);
                end
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
                1:  $readmemh("../source/verif/cpu/multi_cycle/assembly/regs.hex",               DUT.memory.mem);
                // 2:  $readmemh("../source/verif/cpu/multi_cycle/assembly/basic_swlw.hex",         DUT.memory.mem);
                // 3:  $readmemh("../source/verif/cpu/multi_cycle/assembly/border_swlw.hex",        DUT.memory.mem);
                // 4:  $readmemh("../source/verif/cpu/multi_cycle/assembly/rtype.hex",              DUT.memory.mem);
                // 5:  $readmemh("../source/verif/cpu/multi_cycle/assembly/jump.hex",               DUT.memory.mem);
                // 6:  $readmemh("../source/verif/cpu/multi_cycle/assembly/beq.hex",                DUT.memory.mem);
                // 7:  $readmemh("../source/verif/cpu/multi_cycle/assembly/andi.hex",               DUT.memory.mem);
                // 8:  $readmemh("../source/verif/cpu/multi_cycle/assembly/ori.hex",                DUT.memory.mem);
                // 9:  $readmemh("../source/verif/cpu/multi_cycle/assembly/lui.hex",                DUT.memory.mem);
                // 10: $readmemh("../source/verif/cpu/multi_cycle/assembly/sll.hex",                DUT.memory.mem);
                // 11: $readmemh("../source/verif/cpu/multi_cycle/assembly/srl.hex",                DUT.memory.mem);
                // 12: $readmemh("../source/verif/cpu/multi_cycle/assembly/bne.hex",                DUT.memory.mem);
                // 13: $readmemh("../source/verif/cpu/multi_cycle/assembly/blt.hex",                DUT.memory.mem);
                // 14: $readmemh("../source/verif/cpu/multi_cycle/assembly/fibonacci.hex",          DUT.memory.mem);
                // 15: $readmemh("../source/verif/cpu/multi_cycle/assembly/fibonacci_overflow.hex", DUT.memory.mem);
                // default:
                    // $readmemh("../source/verif/cpu/multi_cycle/assembly/integration.hex",        DUT.memory.mem);
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

    // regs_test()
    // Test goal:
    //   - Validates basic register writes for the regs program (test_id=1).
    // PASS criteria:
    //   - R1=1, R2=2, R3=3
    //------------------------------------------------------------------------------
    task automatic regs_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING REGS TESTS [1] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd1);
            check_reg(2, DUT.register_file.regs[2], 32'd2);
            check_reg(3, DUT.register_file.regs[3], 32'd3);
        end
    endtask

    //------------------------------------------------------------------------------
    // basic_swlw_test()
    // Test goal:
    //   - Validates SW/LW basic path and addressing (test_id=2).
    // PASS criteria:
    //   - R1=42 stored at MEM[0], later loaded into R2=42
    //------------------------------------------------------------------------------
   // check_basic_swlw()
    // Test goal:
    //   - Validates SW/LW basic path and addressing (test_id=2).
    // PASS criteria:
    //   - R1=42 stored at MEM[0], later loaded into R2=42
    //------------------------------------------------------------------------------
    task automatic basic_swlw_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BASIC SW/LW TESTS [2] ", `ANSI_RST});
            $display({`ANSI_BOLD, "--------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd42);
            check_mem(0, DUT.memory.mem[0], 32'd42);
            check_reg(2, DUT.register_file.regs[2], 32'd42);
        end
    endtask

    //------------------------------------------------------------------------------
    // border_swlw_test()
    // Test goal:
    //   - Edge cases for immediates/sign extension and memory bounds (test_id=3).
    // PASS criteria:
    //   - Specific signed boundary values in registers and MEM[255].
    //------------------------------------------------------------------------------
    task automatic border_swlw_test;
        int mem_word_idx;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BORDER SW/LW TESTS [3] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------", `ANSI_RST});
            mem_word_idx = (8'hFF >> 2);
            check_reg(1, DUT.register_file.regs[1],           32'd32767);
            check_reg(2, DUT.register_file.regs[2],          -32'sd32768);
            check_reg(3, DUT.register_file.regs[3],          -32'sd1);
            check_mem(mem_word_idx, DUT.memory.mem[mem_word_idx], -32'sd1);
            check_reg(4, DUT.register_file.regs[4],          -32'sd1);
            check_reg(5, DUT.register_file.regs[5],           32'd0);
        end
    endtask

    //------------------------------------------------------------------------------
    // rtype_test()
    // Test goal:
    //   - Validates core ALU R-type operations (test_id=4).
    // PASS criteria:
    //   - Expected values in R1..R8 after executing rtype.hex.
    //------------------------------------------------------------------------------
    task automatic rtype_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING R-TYPE (ALU) TESTS [4] ", `ANSI_RST});
            $display({`ANSI_BOLD, "-------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd5);
            check_reg(2, DUT.register_file.regs[2], 32'd3);
            check_reg(3, DUT.register_file.regs[3], 32'd8);
            check_reg(4, DUT.register_file.regs[4], 32'd2);
            check_reg(5, DUT.register_file.regs[5], 32'd1);
            check_reg(6, DUT.register_file.regs[6], 32'd7);
            check_reg(7, DUT.register_file.regs[7], 32'd1);
            check_reg(8, DUT.register_file.regs[8], 32'd0);
        end
    endtask

    //------------------------------------------------------------------------------
    // jump_test()
    // Test goal:
    //   - Validates jump control-flow updates (test_id=5).
    // PASS criteria:
    //   - Expected registers after jump test program.
    //------------------------------------------------------------------------------
    task automatic jump_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING JMP TESTS [5] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd1);
            check_reg(2, DUT.register_file.regs[2], 32'd0);
            check_reg(3, DUT.register_file.regs[3], 32'd0);
            check_reg(4, DUT.register_file.regs[4], 32'd4);
        end
    endtask

    //------------------------------------------------------------------------------
    // beq_test()
    // Test goal:
    //   - Validates BEQ behavior (taken / not taken) and loop correctness (test_id=6).
    // PASS criteria:
    //   - Expected registers after beq program.
    //------------------------------------------------------------------------------
    task automatic beq_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BEQ TESTS [6] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd5);
            check_reg(2, DUT.register_file.regs[2], 32'd5);
            check_reg(3, DUT.register_file.regs[3], 32'd0);
            check_reg(4, DUT.register_file.regs[4], 32'd7);
            check_reg(5, DUT.register_file.regs[5], 32'd9);
            check_reg(6, DUT.register_file.regs[6], 32'd123);
        end
    endtask

    //------------------------------------------------------------------------------
    // andi_test()
    // Test goal:
    //   - Validates ANDI zero-extension and bit masking (test_id=7).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic andi_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ANDi TESTS [7] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd305397760);
            check_reg(2, DUT.register_file.regs[2], 32'd305398015);
            check_reg(3, DUT.register_file.regs[3], 32'd15);
            check_reg(4, DUT.register_file.regs[4], 32'd240);
            check_mem(0, DUT.memory.mem[0], 32'd15);
            check_mem(4, DUT.memory.mem[4], 32'd240);
        end
    endtask

    //------------------------------------------------------------------------------
    // ori_test()
    // Test goal:
    //   - Validates ORI zero-extension and bit assembly (test_id=8).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic ori_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING ORi TESTS [8] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd0);
            check_reg(2, DUT.register_file.regs[2], 32'd1);
            check_reg(3, DUT.register_file.regs[3], 32'd241);
            check_reg(4, DUT.register_file.regs[4], 32'd3855);
            check_reg(5, DUT.register_file.regs[5], 32'd4095);
            check_mem(0, DUT.memory.mem[0], 32'd241);
            check_mem(4, DUT.memory.mem[4], 32'd4095);
        end
    endtask

    //------------------------------------------------------------------------------
    // lui_test()
    // Test goal:
    //   - Validates LUI placement (upper 16 bits) and subsequent ops (test_id=9).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic lui_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING LUI TESTS [9] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd305397760);
            check_reg(2, DUT.register_file.regs[2], 32'd0);
            check_reg(3, DUT.register_file.regs[3], 32'd4294901760);
            check_reg(4, DUT.register_file.regs[4], 32'd305441741);
            check_mem(0, DUT.memory.mem[0], 32'd305397760);
            check_mem(4, DUT.memory.mem[4], 32'd4294901760);
            check_mem(8, DUT.memory.mem[8], 32'd305441741);
        end
    endtask

    //------------------------------------------------------------------------------
    // sll_test()
    // Test goal:
    //   - Validates SLL shifting and edge conditions (test_id=10).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic sll_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SLL TESTS [10] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd1);
            check_reg(2, DUT.register_file.regs[2], 32'd16);
            check_reg(3, DUT.register_file.regs[3], 32'd32);
            check_reg(4, DUT.register_file.regs[4], 32'd240);
            check_reg(5, DUT.register_file.regs[5], 32'd61440);
            check_mem(0, DUT.memory.mem[0], 32'd16);
            check_mem(4, DUT.memory.mem[4], 32'd61440);
        end
    endtask

    //------------------------------------------------------------------------------
    // srl_test()
    // Test goal:
    //   - Validates SRL logical right shift and edge conditions (test_id=11).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic srl_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING SRL TESTS [11] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd2147483648);
            check_reg(2, DUT.register_file.regs[2], 32'd1073741824);
            check_reg(3, DUT.register_file.regs[3], 32'd240);
            check_reg(4, DUT.register_file.regs[4], 32'd15);
            check_reg(5, DUT.register_file.regs[5], 32'd0);
            check_mem(0, DUT.memory.mem[0], 32'd1073741824);
            check_mem(4, DUT.memory.mem[4], 32'd15);
        end
    endtask

    //------------------------------------------------------------------------------
    // bne_test()
    // Test goal:
    //   - Validates BNE behavior (taken / not taken) (test_id=12).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic bne_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BNE TESTS [12] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1, DUT.register_file.regs[1], 32'd1);
            check_reg(2, DUT.register_file.regs[2], 32'd2);
            check_reg(3, DUT.register_file.regs[3], 32'd0);
            check_reg(4, DUT.register_file.regs[4], 32'd5);
            check_reg(5, DUT.register_file.regs[5], 32'd5);
            check_reg(6, DUT.register_file.regs[6], 32'd13107);
            check_mem(0, DUT.memory.mem[0], 32'd13107);
        end
    endtask
    //------------------------------------------------------------------------------
    // blt_test()
    // Test goal:
    //   - Validates BLT behavior (taken) (test_id=13).
    // PASS criteria:
    //   - Expected regs + memory results.
    //------------------------------------------------------------------------------
    task automatic blt_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING BLT TESTS [13] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_mem(0, DUT.memory.mem[0], 32'd1);
            check_mem(1, DUT.memory.mem[1], 32'd1);
            check_mem(2, DUT.memory.mem[2], 32'd1);
        end
    endtask
    //------------------------------------------------------------------------------
    // fibonacci_test()
    // Test goal:
    //   - Validates a longer program with loops and multiple instructions (test_id=14).
    // PASS criteria:
    //   - Expected Fibonacci sequence values in registers and memory.
    //   - Final success flag set to 1, and fib(20)=4181 stored in MEM[31].
        task automatic fibonacci_test;
            begin
                $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
                $write({`ANSI_BOLD, " RUNNING FIBONACCI TESTS [14] ", `ANSI_RST});
                $display({`ANSI_BOLD, "---------------", `ANSI_RST});
                check_reg(0, DUT.register_file.regs[0],  32'h0000);
                check_reg(1, DUT.register_file.regs[1],  32'h0A18);
                check_reg(2, DUT.register_file.regs[2],  32'h1055);
                check_reg(3, DUT.register_file.regs[3],  32'h1055);
                check_reg(4, DUT.register_file.regs[4],  32'h0014);
                check_reg(5, DUT.register_file.regs[5],  32'h0014);
                check_reg(6, DUT.register_file.regs[6],  32'h0014);
                check_reg(7, DUT.register_file.regs[7],  32'h0001);
                check_mem(0,  DUT.memory.mem[0],  32'h0000);
                check_mem(1,  DUT.memory.mem[1],  32'h0001);
                check_mem(2,  DUT.memory.mem[2],  32'h0001);
                check_mem(3,  DUT.memory.mem[3],  32'h0002);
                check_mem(4,  DUT.memory.mem[4],  32'h0003);
                check_mem(5,  DUT.memory.mem[5],  32'h0005);
                check_mem(6,  DUT.memory.mem[6],  32'h0008);
                check_mem(7,  DUT.memory.mem[7],  32'h000D);
                check_mem(8,  DUT.memory.mem[8],  32'h0015);
                check_mem(9,  DUT.memory.mem[9],  32'h0022);
                check_mem(10, DUT.memory.mem[10], 32'h0037);
                check_mem(11, DUT.memory.mem[11], 32'h0059);
                check_mem(12, DUT.memory.mem[12], 32'h0090);
                check_mem(13, DUT.memory.mem[13], 32'h00E9);
                check_mem(14, DUT.memory.mem[14], 32'h0179);
                check_mem(15, DUT.memory.mem[15], 32'h0262);
                check_mem(16, DUT.memory.mem[16], 32'h03DB);
                check_mem(17, DUT.memory.mem[17], 32'h063D);
                check_mem(18, DUT.memory.mem[18], 32'h0A18);
                check_mem(19, DUT.memory.mem[19], 32'h1055);
                check_mem(30, DUT.memory.mem[30], 32'h0001);
                $display({`ANSI_BLU, "   Success flag (should be 1)", `ANSI_RST});
                check_mem(31, DUT.memory.mem[31], 32'h1055);
                $display({`ANSI_BLU, "   Stores final Fibonacci value (fib(20) = 4181)", `ANSI_RST});
            end
    endtask
    //------------------------------------------------------------------------------
    // fibonacci_overflow_test()
    // Test goal:
    //   - Validates behavior when Fibonacci sequence exceeds 32-bit limit (test_id=15).
    // PASS criteria:
    //   - Expected overflowed value in R1 and MEM[0] (fib(47) = 2971215073).
        task automatic fibonacci_overflow_test;
            begin
                $write({`ANSI_BOLD, "-----------------", `ANSI_RST});
                $write({`ANSI_BOLD, " RUNNING FIBONACCI OVERFLOW TESTS [15] ", `ANSI_RST});
                $display({`ANSI_BOLD, "---------------", `ANSI_RST});
                check_reg(0, DUT.register_file.regs[0],  32'h00000000);
                check_reg(1, DUT.register_file.regs[1],  32'h43A53F82);
                check_reg(2, DUT.register_file.regs[2],  32'h6D73E55F);
                check_reg(3, DUT.register_file.regs[3],  32'hB11924E1);
                check_reg(4, DUT.register_file.regs[4],  32'h0000002F);
                check_reg(5, DUT.register_file.regs[5],  32'h00000031);
                check_reg(6, DUT.register_file.regs[6],  32'h0000002F);
                check_reg(7, DUT.register_file.regs[7],  32'h00000001);
                check_reg(8, DUT.register_file.regs[8],  32'h00000001);
                check_reg(9, DUT.register_file.regs[9],  32'h00000001);
                check_mem(0,  DUT.memory.mem[0],  32'h00000000);
                check_mem(1,  DUT.memory.mem[1],  32'h00000001);
                check_mem(2,  DUT.memory.mem[2],  32'h00000001);
                check_mem(3,  DUT.memory.mem[3],  32'h00000002);
                check_mem(4,  DUT.memory.mem[4],  32'h00000003);
                check_mem(5,  DUT.memory.mem[5],  32'h00000005);
                check_mem(6,  DUT.memory.mem[6],  32'h00000008);
                check_mem(7,  DUT.memory.mem[7],  32'h0000000D);
                check_mem(8,  DUT.memory.mem[8],  32'h00000015);
                check_mem(9,  DUT.memory.mem[9],  32'h00000022);
                check_mem(10, DUT.memory.mem[10], 32'h00000037);
                check_mem(11, DUT.memory.mem[11], 32'h00000059);
                check_mem(12, DUT.memory.mem[12], 32'h00000090);
                check_mem(13, DUT.memory.mem[13], 32'h000000E9);
                check_mem(14, DUT.memory.mem[14], 32'h00000179);
                check_mem(15, DUT.memory.mem[15], 32'h00000262);
                check_mem(16, DUT.memory.mem[16], 32'h000003DB);
                check_mem(17, DUT.memory.mem[17], 32'h0000063D);
                check_mem(18, DUT.memory.mem[18], 32'h00000A18);
                check_mem(19, DUT.memory.mem[19], 32'h00001055);
                check_mem(20, DUT.memory.mem[20], 32'h00001A6D);
                check_mem(21, DUT.memory.mem[21], 32'h00002AC2);
                check_mem(22, DUT.memory.mem[22], 32'h0000452F);
                check_mem(23, DUT.memory.mem[23], 32'h00006FF1);
                check_mem(24, DUT.memory.mem[24], 32'h0000B520);
                check_mem(25, DUT.memory.mem[25], 32'h00012511);
                check_mem(26, DUT.memory.mem[26], 32'h0001DA31);
                check_mem(27, DUT.memory.mem[27], 32'h0002FF42);
                check_mem(28, DUT.memory.mem[28], 32'h0004D973);
                check_mem(29, DUT.memory.mem[29], 32'h0007D8B5);
                check_mem(33, DUT.memory.mem[33], 32'h0035C7E2);
                check_mem(34, DUT.memory.mem[34], 32'h005704E7);
                check_mem(35, DUT.memory.mem[35], 32'h008CCCC9);
                check_mem(36, DUT.memory.mem[36], 32'h00E3D1B0);
                check_mem(37, DUT.memory.mem[37], 32'h01709E79);
                check_mem(38, DUT.memory.mem[38], 32'h02547029);
                check_mem(39, DUT.memory.mem[39], 32'h03C50EA2);
                check_mem(40, DUT.memory.mem[40], 32'h06197ECB);
                check_mem(41, DUT.memory.mem[41], 32'h09DE8D6D);
                check_mem(42, DUT.memory.mem[42], 32'h0FF80C38);
                check_mem(43, DUT.memory.mem[43], 32'h19D699A5);
                check_mem(44, DUT.memory.mem[44], 32'h29CEA5DD);
                check_mem(45, DUT.memory.mem[45], 32'h43A53F82);
                check_mem(46, DUT.memory.mem[46], 32'h6D73E55F);
                check_mem(30, DUT.memory.mem[30], 32'h00000001);
                $display({`ANSI_BLU, "   Success flag (should be 1)", `ANSI_RST});
                check_mem(31, DUT.memory.mem[31], 32'h6D73E55F);
                $display({`ANSI_BLU, "   Last valid Fibonacci value (fib(46) = 1836311903)", `ANSI_RST});
                check_mem(32, DUT.memory.mem[32], 32'hB11924E1);
                $display({`ANSI_BLU, "   Overflow detected | value (fib(47) wrapped = 2971215073)", `ANSI_RST});
            end
        endtask
    //------------------------------------------------------------------------------
    // integration_test()
    // Test goal:
    //   - Validates multiple instructions working together (default test).
    // PASS criteria:
    //   - Expected final architectural state (selected regs + memory locations).
    //------------------------------------------------------------------------------
    task automatic integration_test;
        begin
            $write({`ANSI_BOLD, "-----------------------", `ANSI_RST});
            $write({`ANSI_BOLD, " RUNNING INTEGRATION TESTS [default] ", `ANSI_RST});
            $display({`ANSI_BOLD, "---------------", `ANSI_RST});
            check_reg(1,  DUT.register_file.regs[1],  32'd10);
            check_reg(2,  DUT.register_file.regs[2],  32'd15);
            check_reg(3,  DUT.register_file.regs[3],  32'd65536);
            check_reg(4,  DUT.register_file.regs[4],  32'd40);
            check_reg(5,  DUT.register_file.regs[5],  32'd20);
            check_reg(7,  DUT.register_file.regs[7],  32'd15);
            check_reg(8,  DUT.register_file.regs[8],  32'd31);
            check_reg(9,  DUT.register_file.regs[9],  32'd15);
            check_reg(10, DUT.register_file.regs[10], 32'd25);
            check_reg(11, DUT.register_file.regs[11], 32'd10);
            check_mem(0,  DUT.memory.mem[0],   32'd25);
            check_reg(12, DUT.register_file.regs[12], 32'd25);
            check_reg(13, DUT.register_file.regs[13], 32'd1);
            check_reg(14, DUT.register_file.regs[14], 32'd0);
            check_mem(1,  DUT.memory.mem[1],   32'd0);
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
    //   - TIMEOUT if halt is not observed within max_cycles
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
                if (DUT.halt) begin
                    $display("\033[1;34m-> HALT detected @%0t (PC=0x%08h)\033[0m", $time, DUT.pc);
                    i = max_cycles; // Icarus workaround to break loop
                end
            end

            // Enforce termination condition
            if (DUT.halt != 1'b1) begin
                $fatal(1,
                       "\033[1;31m\nTIMEOUT: HALT not reached after %0d max_cycles (PC=0x%08h) @%0t\033[0m",
                       max_cycles, DUT.pc, $time);
            end

            // 5) Check results
            case (id)
                1:  regs_test();
                2:  basic_swlw_test();
                3:  border_swlw_test();
                4:  rtype_test_test();
                5:  jump_test();
                6:  beq_test();
                7:  andi_test();
                8:  ori_test();
                9:  lui_test();
                10: sll_test();
                11: srl_test();
                12: bne_test();
                13: blt_test();
                14: fibonacci_test();
                15: fibonacci_overflow_test();
                default: integration_test();
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

    function string get_state_name(input [3:0] state);
        case (state)
            4'd0:  return "FETCH";
            4'd1:  return "DECODE";
            4'd2:  return "MEM_ADR";
            4'd3:  return "MEM_READ";
            4'd4:  return "MEM_WB";
            4'd5:  return "MEM_WRITE";
            4'd6:  return "EXEC_R";
            4'd7:  return "ALU_WB";
            4'd8:  return "BRANCH";
            4'd9:  return "IMM_WB";
            4'd10: return "JUMP";
            4'd11: return "EXEC_IMM";
            4'd12: return "HALT";
            default: return "UNKNOWN";
        endcase
    endfunction
endmodule