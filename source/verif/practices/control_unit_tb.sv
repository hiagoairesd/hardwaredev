module control_unit_tb();

    localparam CTRL_WORD_W = 9;
    localparam INSTR_W = 32;

    reg [INSTR_W-1:0] instr;
    wire halt;
    wire [2:0] aluControl;
    wire       regWrite;
    wire       regDst;
    wire       aluSrc;
    wire       take_branch;
    wire       memWrite;
    wire       memtoReg;
    wire       jump;
    wire       is_shift;
    wire       imm_is_zext;
    
    // Declare input signals to control_unit
    reg        is_zero;
    reg        signed_less;

    control_unit DUT (
        .instr          (instr),
        .aluOut_is_zero (is_zero),
        .signed_less    (signed_less),
        .aluControl     (aluControl),
        .regWrite       (regWrite),
        .regDst         (regDst),
        .aluSrc         (aluSrc),
        .take_branch    (take_branch),
        .memWrite       (memWrite),
        .memtoReg       (memtoReg),
        .jump           (jump),
        .is_shift       (is_shift),
        .imm_is_zext    (imm_is_zext),
        .halt           (halt)
    );

    // Extended check task that verifies control word + special signals
    task check_extended;
        input logic [CTRL_WORD_W-1:0]  exp_word;
        input logic                    exp_take_branch;
        input logic                    exp_is_shift;
        input logic                    exp_imm_is_zext;
        input logic                    exp_halt;
        begin
            if(DUT.word !== exp_word) begin
                $display("TEST FAILED - Control Word Mismatch");
                $display("At time %0d \nword = %b \t opcode = %b \t function = %b",
                            $time, DUT.word, DUT.opcode, DUT.funct);
                $display("'word' should be: %b", exp_word);
                $finish;
            end
            
            if(take_branch !== exp_take_branch) begin
                $display("TEST FAILED - take_branch Mismatch");
                $display("At time %0d: take_branch = %b, expected %b", 
                            $time, take_branch, exp_take_branch);
                $finish;
            end
            
            if(is_shift !== exp_is_shift) begin
                $display("TEST FAILED - is_shift Mismatch");
                $display("At time %0d: is_shift = %b, expected %b", 
                            $time, is_shift, exp_is_shift);
                $finish;
            end
            
            if(imm_is_zext !== exp_imm_is_zext) begin
                $display("TEST FAILED - imm_is_zext Mismatch");
                $display("At time %0d: imm_is_zext = %b, expected %b", 
                            $time, imm_is_zext, exp_imm_is_zext);
                $finish;
            end
            
            if(halt !== exp_halt) begin
                $display("TEST FAILED - halt Mismatch");
                $display("At time %0d: halt = %b, expected %b", 
                            $time, halt, exp_halt);
                $finish;
            end
            
            $display("At time %0d: word=%b | take_branch=%b | is_shift=%b | imm_is_zext=%b | halt=%b OK",
                        $time, DUT.word, take_branch, is_shift, imm_is_zext, halt);
        end
    endtask

    // Simplified check task for backward compatibility
    task check;
        input logic [CTRL_WORD_W-1:0]      exp_word;
        begin
            if(DUT.word !== exp_word) begin
                $display("TEST FAILED");
                $display("At time %0d \nword = %b \t opcode = %b \t function = %b",
                            $time, DUT.word, DUT.opcode, DUT.funct);
                $display("'word' should be: %b", exp_word);
                $finish;
            end
            else begin 
                $display("At time %0d \nword = %b \t opcode = %b \t function = %b",
                            $time, DUT.word, DUT.opcode, DUT.funct);
            end
        end
    endtask

    initial begin
        // Initialize inputs used for branch decision logic
        is_zero     = 1'b0;
        signed_less = 1'b0;
        
        // R-TYPE OPERATIONS (is_shift=0, imm_is_zext=0, halt=0) 
        $display("\n------------------------------------ R-TYPE OPERATIONS ------------------------------------\n");
        
        $display("\t\t\tADD (no shift, no zero-ext)");
        instr = 32'b00000001000010010101000000100000; 
        #5 check_extended(9'b110010000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tSUB (no shift, no zero-ext)");
        instr = 32'b00000001011011000110100000100010; 
        #5 check_extended(9'b110110000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tAND (no shift, no zero-ext)");
        instr = 32'b00000001110011111000000000100100;
        #5 check_extended(9'b110000000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tOR (no shift, no zero-ext)");
        instr = 32'b00000001000010010101000000100101; 
        #5 check_extended(9'b110001000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tSLT (no shift, no zero-ext)");
        instr = 32'b00000001010010110110000000101010; 
        #5 check_extended(9'b110111000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // SHIFT INSTRUCTIONS (is_shift=1) 
        $display("\n------------------------------------ SHIFT INSTRUCTIONS ------------------------------------\n");
        
        $display("\t\t\tSLL (is_shift=1)");
        instr = 32'b00000001010010110100000000000000; 
        #5 check_extended(9'b110011000, 1'b0, 1'b1, 1'b0, 1'b0);
        
        $display("\t\t\tSRL (is_shift=1)");
        instr = 32'b00000001010010110100000000000010; 
        #5 check_extended(9'b110100000, 1'b0, 1'b1, 1'b0, 1'b0);
        
        // LOAD/STORE (no shift, no zero-ext, no take_branch) 
        $display("\n------------------------------------ LOAD/STORE OPERATIONS ------------------------------------\n");
        
        $display("\t\t\tLW (load)");
        instr = 32'b10001111101010000000000000001100; 
        #5 check_extended(9'b101010010, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tSW (store)");
        instr = 32'b10101111101010110000000000000000; 
        #5 check_extended(9'b001010100, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // BRANCH INSTRUCTIONS (take_branch varies with is_zero/signed_less) 
        $display("\n------------------------------------ BRANCH INSTRUCTIONS ------------------------------------\n");
        
        $display("\t\t\tBEQ - take_branch=1 when is_zero=1");
        is_zero = 1'b1;
        instr = 32'b00010001001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b1, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tBEQ - take_branch=0 when is_zero=0");
        is_zero = 1'b0;
        instr = 32'b00010001001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tBNE - take_branch=1 when is_zero=0");
        is_zero = 1'b0;
        instr = 32'b00010101001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b1, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tBNE - take_branch=0 when is_zero=1");
        is_zero = 1'b1;
        instr = 32'b00010101001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tBLT - take_branch=1 when signed_less=1");
        is_zero = 1'b0;
        signed_less = 1'b1;
        instr = 32'b00011001001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b1, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tBLT - take_branch=0 when signed_less=0");
        signed_less = 1'b0;
        instr = 32'b00011001001010100000000000000100; 
        #5 check_extended(9'b000110000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // IMMEDIATE OPERATIONS WITH ZERO-EXTEND 
        $display("\n------------------------------------ IMMEDIATE OPERATIONS ------------------------------------\n");
        
        $display("\t\t\tADDi (no zero-ext, sign-extend)");
        instr = 32'b00100001000010010000000000000101; 
        #5 check_extended(9'b101010000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\t\t\tANDI (imm_is_zext=1, zero-extend)");
        instr = 32'b00110001000010010000000000000101; 
        #5 check_extended(9'b101000000, 1'b0, 1'b0, 1'b1, 1'b0);
        
        $display("\t\t\tORI (imm_is_zext=1, zero-extend)");
        instr = 32'b00110101000010010000000000000101; 
        #5 check_extended(9'b101001000, 1'b0, 1'b0, 1'b1, 1'b0);
        
        $display("\t\t\tLUI (imm_is_zext=1, zero-extend)");
        instr = 32'b00111101000010010000000000000101; 
        #5 check_extended(9'b101101000, 1'b0, 1'b0, 1'b1, 1'b0);
        
        // JUMP INSTRUCTION 
        $display("\n------------------------------------ JUMP INSTRUCTION ------------------------------------\n");
        
        $display("\t\t\tJ (jump, no shift, no zero-ext)");
        instr = 32'b00001000000000000000000000000100; 
        #5 check_extended(9'b000000001, 1'b0, 1'b0, 1'b0, 1'b0);
        
        // HALT 
        $display("\n------------------------------------ HALT INSTRUCTION ------------------------------------\n");
        
        $display("\t\t\tHALT (halt=1)");
        instr = 32'b11111100000000000000000000000000; 
        #5 check_extended(9'b000000000, 1'b0, 1'b0, 1'b0, 1'b1);
        
        // INVALID INSTRUCTIONS 
        $display("\n------------------------------------ INVALID INSTRUCTIONS ------------------------------------\n");
        
        $display("\t\t\tInvalid opcode (all zeros except bits 27-26)");
        instr = 32'b01010100000000000000000000000000; 
        #5 check_extended(9'b000000000, 1'b0, 1'b0, 1'b0, 1'b0);
        
        $display("\n\t\t\t\tALL TESTS PASSED");
        $finish;
    end

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);
    end
endmodule