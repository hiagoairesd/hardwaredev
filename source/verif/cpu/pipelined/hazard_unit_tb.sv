//=====================================================================================================================================
// HAZARD UNIT TESTBENCH
//=====================================================================================================================================
// Purpose: Verify the hazard unit module detects and resolves data hazards in a pipelined CPU
// Tests: Forwarding logic (forwardAE/B, forwardAD/B) and stall/flush control (F_stall, D_stall, E_flush)
// Patterns:
//   - FORWARDING TESTS: Data hazards resolved via forwarding from M/W stages to E/D stages
//   - STALL/FLUSH TESTS: Load-use hazards and branch hazards requiring pipeline control
//=====================================================================================================================================

module hazard_unit_tb();
    localparam ADDR_W = 5;

    reg              D_branch, E_regWrite, E_memtoReg, M_regWrite, W_regWrite, M_memtoReg;
    reg [ADDR_W-1:0] D_rs, D_rt, E_rs, E_rt;
    reg [ADDR_W-1:0] M_wa3, W_wa3, E_wa3;

    wire [1:0] forwardAE, forwardBE;
    wire       forwardAD, forwardBD;
    wire       F_stall, D_stall, E_flush;

    integer pass_count;

    hazard_unit DUT(
        .D_branch   (D_branch),
        .E_regWrite (E_regWrite),
        .E_memtoReg (E_memtoReg),
        .M_regWrite (M_regWrite),
        .W_regWrite (W_regWrite),
        .M_memtoReg (M_memtoReg),
        .D_rs       (D_rs),
        .D_rt       (D_rt),
        .E_rs       (E_rs),
        .E_rt       (E_rt),
        .M_wa3      (M_wa3),
        .W_wa3      (W_wa3),
        .E_wa3      (E_wa3),
        .forwardAE  (forwardAE),
        .forwardAD  (forwardAD),
        .forwardBE  (forwardBE),
        .forwardBD  (forwardBD),
        .F_stall    (F_stall),
        .D_stall    (D_stall),
        .E_flush    (E_flush)
    );

    //=====================================================================================================================================
    // SECTION 1: HELPER TASKS FOR VALIDATION AND REPORTING
    //=====================================================================================================================================

    // Check 1-bit signals: Validate actual vs expected and fail fast on mismatch
    task automatic check_eq_1;
        input string signal_name;
        input logic  actual;
        input logic  expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] t=%0t %0s got=%b expected=%b", $time, signal_name, actual, expected);
                $finish;
            end
        end
    endtask

    // Check 2-bit signals: Same as check_eq_1 but for 2-bit wide signals
    task automatic check_eq_2;
        input string      signal_name;
        input logic [1:0] actual;
        input logic [1:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] t=%0t %0s got=%b expected=%b", $time, signal_name, actual, expected);
                $finish;
            end
        end
    endtask

    // Print a section header with visual separator
    task automatic print_section;
        input string title;
        begin
            $display("---------------------------------------------------------------------------------------------------------------------------------");
            $display("\t\t\t\t%0s", title);
        end
    endtask

    // Print a test case title with indentation
    task automatic print_case;
        input string title;
        begin
            $display("\t\t\t%0s", title);
        end
    endtask

    // Print test result with all hazard unit outputs and relevant control signals
    task automatic print_ok;
        begin
            $display(
                "At time %0t: forwardAE=%b | forwardBE=%b | forwardAD=%b | forwardBD=%b | F_stall=%b | D_stall=%b | E_flush=%b | D_branch=%b | E_memtoReg=%b | M_memtoReg=%b | OK\n",
                $time, forwardAE, forwardBE, forwardAD, forwardBD, F_stall, D_stall, E_flush, D_branch, E_memtoReg, M_memtoReg
            );
        end
    endtask

    // Clear all inputs: reset stimuli to neutral state (no hazards)
    task automatic clear_inputs;
        begin 
            D_branch   = 1'b0;
            E_regWrite = 1'b0;
            E_memtoReg = 1'b0;
            M_regWrite = 1'b0;
            W_regWrite = 1'b0;
            M_memtoReg = 1'b0;

            D_rs  = 1'b0; D_rt  = 1'b0;
            E_rs  = 1'b0; E_rt  = 1'b0;
            M_wa3 = 1'b0; W_wa3 = 1'b0; E_wa3 = 1'b0;
        end
    endtask

    // Simulation step: wait 1 time unit for combinational logic to settle
    task automatic step;
        begin
            #1;
        end
    endtask

    // Macro task: validate all 7 hazard unit outputs in one call (forwarding + stall/flush)
    task automatic expect_all;
        input [1:0] exp_fwdAE, exp_fwdBE;
        input       exp_fwdAD, exp_fwdBD;
        input       exp_F_stall, exp_D_stall, exp_E_flush;
        begin
            check_eq_2("forwardAE", forwardAE, exp_fwdAE);
            check_eq_2("forwardBE", forwardBE, exp_fwdBE);
            check_eq_1("forwardAD", forwardAD, exp_fwdAD);
            check_eq_1("forwardBD", forwardBD, exp_fwdBD);
            check_eq_1("F_stall",   F_stall,   exp_F_stall);
            check_eq_1("D_stall",   D_stall,   exp_D_stall);
            check_eq_1("E_flush",   E_flush,   exp_E_flush);
            print_ok();
            pass_count = pass_count + 1;
        end
    endtask

    //=====================================================================================================================================
    // SECTION 2: FORWARDING TEST CASES
    //=====================================================================================================================================

    // Test No Hazard: Registers in E/D stages do not match M/W destination registers
    task automatic test_no_hazard;
        begin
            print_case("No Hazard");
            clear_inputs();
            E_rs = 5'd1; E_rt = 5'd2; D_rs = 5'd3; D_rt = 5'd4;
            step();
            // Expected outputs: forwardAE=00, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=0, D_stall=0, E_flush=0
            expect_all(2'b00, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        end
    endtask

    // Test ForwardAE from Memory: E_rs matches M_wa3 with M_regWrite → forward from M (2'b10)
    task automatic test_forwardAE_from_M;
    begin
        print_case("ForwardAE from Memory Stage");
        clear_inputs();
        E_rs = 5'd10; M_wa3 = 5'd10; M_regWrite = 1'b1;
        step();
        // Expected outputs: forwardAE=10, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=0, D_stall=0, E_flush=0
        expect_all(2'b10, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    end
    endtask

    // Test ForwardAE from Writeback: E_rs matches W_wa3 with W_regWrite → forward from W (2'b01)
    task automatic test_forwardAE_from_W;
        begin
            print_case("forwardAE from W stage");
            clear_inputs();
            E_rs = 5'd11; W_wa3 = 5'd11; W_regWrite = 1'b1;
            step();
            // Expected outputs: forwardAE=01, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=0, D_stall=0, E_flush=0
            expect_all(2'b01, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        end
    endtask

    // Test ForwardBE priority: Both M and W match E_rt → M has priority (2'b10)
    task automatic test_forwardBE_priority_M_over_W;
        begin
            print_case("forwardBE priority M over W");
            clear_inputs();
            E_rt = 5'd12;
            M_wa3 = 5'd12; M_regWrite = 1'b1;
            W_wa3 = 5'd12; W_regWrite = 1'b1;
            step();
            // Expected outputs: forwardAE=00, forwardBE=10, forwardAD=0, forwardBD=0, F_stall=0, D_stall=0, E_flush=0
            expect_all(2'b00, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        end
    endtask

    // Test ForwardAD/BD from Memory: D_rs/D_rt match M_wa3 with M_regWrite → forward for branch resolution
    task automatic test_forward_decode_from_M;
        begin
            print_case("forwardAD/forwardBD from M stage");
            clear_inputs();
            D_rs = 5'd7; D_rt = 5'd8;
            M_wa3 = 5'd7; M_regWrite = 1'b1;
            step();
            check_eq_1("forwardAD", forwardAD, 1'b1);
            check_eq_1("forwardBD", forwardBD, 1'b0);
            print_ok();

            clear_inputs();
            D_rs = 5'd7; D_rt = 5'd8;
            M_wa3 = 5'd8; M_regWrite = 1'b1;
            step();
            check_eq_1("forwardAD", forwardAD, 1'b0);
            check_eq_1("forwardBD", forwardBD, 1'b1);
            print_ok();

            pass_count = pass_count + 1;
        end
    endtask

    //=====================================================================================================================================
    // SECTION 3: STALL/FLUSH TEST CASES
    //=====================================================================================================================================

    // Test Load-use Stall (rs): LW in E stage writes to reg matching D_rs → stall pipeline
    task automatic test_lw_stall_on_D_rs;
        begin
            print_case("Load-use stall (E_rt == D_rs)");
            clear_inputs();
            E_memtoReg = 1'b1;
            E_rt = 5'd4;
            D_rs = 5'd4;
            step();
            // Expected outputs: forwardAE=00, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=1, D_stall=1, E_flush=1
            expect_all(2'b00, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
            //                                    ↑    ↑       ↑
            //                                F_stall D_stall E_flush
        end
    endtask

    // Test Load-use Stall (rt): LW in E stage writes to reg matching D_rt → stall pipeline
    task automatic test_lw_stall_on_D_rt;
        begin
            print_case("Load-use stall (E_rt == D_rt)");
            clear_inputs();
            E_memtoReg = 1'b1;
            E_rt = 5'd9;
            D_rt = 5'd9;
            step();
            // Expected outputs: forwardAE=00, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=1, D_stall=1, E_flush=1
            expect_all(2'b00, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        end
    endtask

    // Test Branch Stall from E: Branch in D has dependency on reg written in E → stall to resolve condition
    task automatic test_branch_stall_from_E;
        begin
            print_case("Branch stall from E stage dependency");
            clear_inputs();
            D_branch = 1'b1;
            E_regWrite = 1'b1;
            E_wa3 = 5'd13;
            D_rs  = 5'd13;
            step();
            // Expected outputs: forwardAE=00, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=1, D_stall=1, E_flush=1
            expect_all(2'b00, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        end
    endtask

    // Test Branch Stall from M: Branch in D has dependency on LW result in M → stall to get loaded data
    task automatic test_branch_stall_from_M_load;
        begin
            print_case("Branch stall from M load dependency");
            clear_inputs();
            D_branch = 1'b1;
            M_memtoReg = 1'b1;
            M_wa3 = 5'd21;
            D_rt  = 5'd21;
            step();
            // Expected outputs: forwardAE=00, forwardBE=00, forwardAD=0, forwardBD=0, F_stall=1, D_stall=1, E_flush=1
            expect_all(2'b00, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        end
    endtask

    //=====================================================================================================================================
    // MAIN TESTBENCH EXECUTION
    //=====================================================================================================================================
    
    initial begin
        step();
        pass_count = 0;
        print_section("FORWARDING TESTS");
        test_no_hazard();
        test_forwardAE_from_M();
        test_forwardAE_from_W();
        test_forwardBE_priority_M_over_W();
        test_forward_decode_from_M();

        print_section("STALL / FLUSH TESTS");
        test_lw_stall_on_D_rs();
        test_lw_stall_on_D_rt();
        test_branch_stall_from_E();
        test_branch_stall_from_M_load();

        $display("");
        $display("\t\t\tALL TESTS PASSED (%0d cases)", pass_count);
        $finish;
    end

    //=====================================================================================================================================
    // SIMULATION CONTROL
    //=====================================================================================================================================

    initial begin
        $dumpfile("hazard_unit.vcd");
        $dumpvars(0, hazard_unit_tb);
    end

    initial begin
        #200;
        $display("[FAIL] Timeout: simulation did not finish in time");
        $finish;
    end
endmodule