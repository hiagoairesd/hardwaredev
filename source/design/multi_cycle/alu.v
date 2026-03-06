module alu #(
    parameter DATA_W = 32
) (
    input  wire [2:0]        aluControl,
    input  wire [DATA_W-1:0] in_a,
    input  wire [DATA_W-1:0] in_b,
    output reg  [DATA_W-1:0] out,
    output wire              is_zero,
    output wire              signed_less
);
    wire [DATA_W-1:0] sub = in_a + ~in_b + 1;

    // Overflow detection for signed subtraction (in_a - in_b):
    // Overflow occurs if:
    // 1) in_a is positive and in_b is negative, and the result is negative
    // 2) in_a is negative and in_b is positive, and the result is positive
    wire ovfw_sub = (in_a[DATA_W-1] ^ in_b[DATA_W-1]) &
                    (in_a[DATA_W-1] ^ sub[DATA_W-1]);

    // If overflow occurs, the sign of the result is incorrect, 
    // so we XOR it with the overflow flag to get the correct signed comparison result.
    assign signed_less = sub[DATA_W-1] ^ ovfw_sub; 

    always @* begin
        case (aluControl)
            3'b000 : out = in_a & in_b;                         // and
            3'b001 : out = in_a | in_b;                         // or
            3'b010 : out = in_a + in_b;                         // add
            3'b110 : out = sub;                                 // sub
            3'b011 : out = in_b << in_a;                        // sll
            3'b100 : out = in_b >> in_a;                        // srl
            3'b101 : out = in_b << 16;                          // lui
            3'b111 : out = {{(DATA_W-1){1'b0}}, signed_less};   // slt
            default: out = {DATA_W{1'b0}};
        endcase
    end
    assign is_zero = (out == {DATA_W{1'b0}});
endmodule