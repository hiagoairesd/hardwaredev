module alu_test();

    localparam WIDTH_TB = 4;

    reg  [2:0]       op_code_tb;
    reg  [WIDTH_TB-1:0] in_a_tb;
    reg  [WIDTH_TB-1:0] in_b_tb;
    wire [WIDTH_TB-1:0] out_tb;
    wire             is_zero_tb;

    alu
    #(
        .WIDTH(WIDTH_TB)
    ) DUT (
        .op_code (op_code_tb),
        .in_a    (in_a_tb),
        .in_b    (in_b_tb),
        .out     (out_tb),
        .is_zero (is_zero_tb)
    );

    task check;
        input                exp_zero;
        input [WIDTH_TB-1:0] exp_out;
        if(is_zero_tb !== exp_zero || out_tb !== exp_out) begin
            $display("TEST FAILED");
            $display("At time %0d \nopcode = %b \t in_a = %b \t in_b = %b \t is_zero = %b \t out = %b",
                        $time, op_code_tb, in_a_tb, in_b_tb, is_zero_tb, out_tb);

            if(is_zero_tb !== exp_zero) begin
                $display("'is_zero' should be: %b", exp_zero);
            end

            if(out_tb !== exp_out) begin
                $display("'out' should be: %b", exp_out);
            end
            $finish;
        end
        else begin 
            $display ("At time %0d \nopcode = %b \t in_a = %b \t in_b = %b \t is_zero = %b \t out = %b",
                        $time, op_code_tb, in_a_tb, in_b_tb, is_zero_tb, out_tb);
        end
    endtask



    initial begin
        op_code_tb= 3'b010; in_a_tb = 4'b0100; in_b_tb = 4'b0001; #10 check(1'b0, 4'b0101);
        op_code_tb= 3'b010; in_a_tb = 4'b1100; in_b_tb = 4'b0011; #10 check(1'b0, 4'b1111);
        op_code_tb= 3'b110; in_a_tb = 4'b1111; in_b_tb = 4'b0011; #10 check(1'b0, 4'b1100);
        op_code_tb= 3'b110; in_a_tb = 4'b0101; in_b_tb = 4'b0100; #10 check(1'b0, 4'b0001);
        op_code_tb= 3'b000; in_a_tb = 4'b1100; in_b_tb = 4'b1100; #10 check(1'b0, 4'b1100);
        op_code_tb= 3'b000; in_a_tb = 4'b1101; in_b_tb = 4'b0001; #10 check(1'b0, 4'b0001);
        op_code_tb= 3'b001; in_a_tb = 4'b0000; in_b_tb = 4'b0001; #10 check(1'b0, 4'b0001);
        op_code_tb= 3'b001; in_a_tb = 4'b1100; in_b_tb = 4'b0001; #10 check(1'b0, 4'b1101);
        op_code_tb= 3'b111; in_a_tb = 4'b1110; in_b_tb = 4'b1100; #10 check(1'b1, 4'b0000);
        op_code_tb= 3'b111; in_a_tb = 4'b0011; in_b_tb = 4'b0100; #10 check(1'b0, 4'b0001);
        $display("\t TEST PASSED");
        $finish;
    end

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_test);
    end
endmodule