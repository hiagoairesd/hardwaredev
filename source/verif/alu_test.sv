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
    )
    alu_dut(
        .op_code (op_code_tb),
        .in_a    (in_a_tb),
        .in_b    (in_b_tb),
        .out     (out_tb),
        .is_zero (is_zero_tb)
    );

    initial begin
        #10
        op_code_tb= 3'b010; in_a_tb = 4'b0100; in_b_tb = 4'b0001;
        #10
        op_code_tb= 3'b010; in_a_tb = 4'b1100; in_b_tb = 4'b0011;
        #10
        op_code_tb= 3'b110; in_a_tb = 4'b1111; in_b_tb = 4'b0011;
        #10
        op_code_tb= 3'b110; in_a_tb = 4'b0101; in_b_tb = 4'b0100;
        #10
        op_code_tb= 3'b000; in_a_tb = 4'b1100; in_b_tb = 4'b1100;
        #10
        op_code_tb= 3'b000; in_a_tb = 4'b1101; in_b_tb = 4'b0001;
        #10
        op_code_tb= 3'b001; in_a_tb = 4'b0000; in_b_tb = 4'b0001;
        #10
        op_code_tb= 3'b001; in_a_tb = 4'b1100; in_b_tb = 4'b0001;
        #10
        op_code_tb= 3'b111; in_a_tb = 4'b1110; in_b_tb = 4'b1100;
        #10
        op_code_tb= 3'b111; in_a_tb = 4'b0011; in_b_tb = 4'b0100;
    end

    initial begin
        $monitor("time: %0d \n op_code= %b \t in_a= %b \t in_b= %b \t out= %b \t is_zero= %b",
                $time, op_code_tb, in_a_tb, in_b_tb, out_tb, is_zero_tb);
    end

    initial begin
        #200 $finish;
    end
    
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_test);
    end
endmodule