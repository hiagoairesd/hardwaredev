module alu #(
    parameter DATA_W = 4
) (
    input  wire [2:0]       opcode,
    input  wire [DATA_W-1:0] in_a,
    input  wire [DATA_W-1:0] in_b,
    output reg  [DATA_W-1:0] out,
    output wire             is_zero
);

    always @* begin
        case (opcode)
            3'b010 : out = in_a + in_b;      // add
            3'b110 : out = in_a + ~in_b + 1; // sub
            3'b000 : out = in_a & in_b;      // and
            3'b001 : out = in_a | in_b;      // or
            3'b111 : out = (in_a < in_b) ? {{DATA_W-1{1'b0}}, 1'b1} : {DATA_W{1'b0}}; // less than
            default: out = {DATA_W{1'b0}};
        endcase
    end
    assign is_zero = (out == {DATA_W{1'b0}}) ? 1'b1 : 1'b0;
endmodule