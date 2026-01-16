module control_unit_test();

    localparam CTRL_WORD_W = 10;
    localparam INSTR_W = 32;

    reg [INSTR_W-1:0] instr;
    wire [CTRL_WORD_W-1:0]  word;
    wire halt;

    control_unit
    #(
        .CTRL_WORD_W(CTRL_WORD_W),
        .INSTR_W(INSTR_W)
    ) DUT (
        .instr (instr),
        .word (word),
        .halt (halt)
    );

    // extract opcode and funct from instr
    task automatic decode_instr(
        input  logic [INSTR_W-1:0] instr_i,
        output logic [5:0]             opcode,
        output logic [5:0]             funct
        );
        opcode = instr_i[31:26];
        funct  = instr_i[5:0];
    endtask


    task check;
        input logic [CTRL_WORD_W-1:0]      exp_word;
        
        logic [5:0] op, fn;
        begin
            decode_instr(instr, op, fn);

            if(word !== exp_word) begin
                $display("TEST FAILED");
                $display("At time %0d \nword = %b \t opcode = %b \t function = %b",
                            $time, word, op, fn);
                $display("'word' should be: %b", exp_word);
                $finish;
            end
            else begin 
                $display("At time %0d \nword = %b \t opcode = %b \t function = %b",
                            $time, word, op, fn);
            end
        end
    endtask

    initial begin
        $display("\t\tADD");
        instr = 32'b00000001000010010101000000100000; #5 check(10'b1100100000);
        instr = 32'b00000010001100101001100000100000; #5 check(10'b1100100000);
        instr = 32'b00000000100001010011000000100000; #5 check(10'b1100100000);
        $display("\t\tSUB");
        instr = 32'b00000001011011000110100000100010; #5 check(10'b1101100000);
        instr = 32'b00000010000100011001000000100010; #5 check(10'b1101100000);
        instr = 32'b00000000110001110100000000100010; #5 check(10'b1101100000);
        $display("\t\tAND");
        instr = 32'b00000001110011111000000000100100; #5 check(10'b1100000000);
        instr = 32'b00000010110101111100000000100100; #5 check(10'b1100000000);
        instr = 32'b00000000011001010100100000100100; #5 check(10'b1100000000);
        $display("\t\tOR");
        instr = 32'b00000001000010010101000000100101; #5 check(10'b1100010000);
        instr = 32'b00000010010100111010000000100101; #5 check(10'b1100010000);
        instr = 32'b00000000100000100100000000100101; #5 check(10'b1100010000);
        $display("\t\tSLT");
        instr = 32'b00000001010010110110000000101010; #5 check(10'b1101110000);
        instr = 32'b00000010000100011001000000101010; #5 check(10'b1101110000);
        instr = 32'b00000000110001110100000000101010; #5 check(10'b1101110000);
        $display("\t\tLW");
        instr = 32'b10001111101010000000000000001100; #5 check(10'b1010100010);
        instr = 32'b10001111110100011111111111111000; #5 check(10'b1010100010);
        instr = 32'b10001101010001000000010000000000; #5 check(10'b1010100010);
        $display("\t\tSW");
        instr = 32'b10101111101010110000000000000000; #5 check(10'b0x101001x0);
        instr = 32'b10101101010001010000000000000100; #5 check(10'b0x101001x0);
        instr = 32'b10101110010100110000000000001000; #5 check(10'b0x101001x0);
        $display("\t\tBEQ");
        instr = 32'b00010001001010100000000000000100; #5 check(10'b0x011010x0);
        instr = 32'b00010010001100100000000000010000; #5 check(10'b0x011010x0);
        instr = 32'b00010000100001011111111111111100; #5 check(10'b0x011010x0);
        $display("\t\tADDi");
        instr = 32'b00100001000010010000000000000101; #5 check(10'b1010100000);
        instr = 32'b00100010001100100000000000100000; #5 check(10'b1010100000);
        instr = 32'b00100000100001011111111111111111; #5 check(10'b1010100000);
        $display("\t\tJ");
        instr = 32'b00001000000000000000000000000100; #5 check(10'b0xxxxxxxx1);
        instr = 32'b00001000000000000000000001000000; #5 check(10'b0xxxxxxxx1);
        instr = 32'b00001000000000000000100000000000; #5 check(10'b0xxxxxxxx1);
        $display("\t\tDefault");
        instr = 32'b11111100000000000000000000000000; #5 check(10'b0000000000);
        instr = 32'b01010100000000000000000000000000; #5 check(10'b0000000000);
        instr = 32'b00000001010010110110000000000001; #5 check(10'b0000000000);
        $display("\t\t TEST PASSED");
        $finish;
    end

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_test);
    end
endmodule