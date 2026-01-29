module proc_ripple_carry_adder (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output reg  [7:0] s,
    output reg        cout
);
    always @* begin
        {cout, s} = a + b + cin;
    end
endmodule
