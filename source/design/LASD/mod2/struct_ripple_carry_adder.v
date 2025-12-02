module full_adder (
    input  wire a, b, cin,
    output wire sum, cout
);
    assign {cout, sum} = a + b + cin;

endmodule

//------------------------------------------------------------
// structural description of an 8-bit ripple carry adder
module 8bit_ripple_carry_adder (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire Cin,
    output wire [7:0] s,
    output wire cout
);
    wire [6:0] carry;

    full_adder fa0 (a[0], b[0], Cin,     s[0], carry[0]);
    full_adder fa1 (a[1], b[1], carry[0], s[1], carry[1]);
    full_adder fa2 (a[2], b[2], carry[1], s[2], carry[2]);
    full_adder fa3 (a[3], b[3], carry[2], s[3], carry[3]);
    full_adder fa4 (a[4], b[4], carry[3], s[4], carry[4]);
    full_adder fa5 (a[5], b[5], carry[4], s[5], carry[5]);
    full_adder fa6 (a[6], b[6], carry[5], s[6], carry[6]);
    full_adder fa7 (a[7], b[7], carry[6], s[7], cout);

endmodule
