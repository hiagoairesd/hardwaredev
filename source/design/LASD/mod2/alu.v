module alu #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst,
    input  wire [2:0]       op_code,
    input  wire [WIDTH-1:0] in_a,
    input  wire [WIDTH-1:0] in_b,
    output reg  [WIDTH-1:0] out,
    output wire             is_zero
);

    always @(posedge clk) begin
        if(rst) begin
            out <= {WIDTH{1'b0}};
            is_zero  <= 1'b0;
        
        end else case (opcode)
            3'b010 : out <= in_a + in_b;      // add
            3'b110 : out <= in_a + ~in_b + 1; // sub
            3'b000 : out <= in_a & in_b;      // and
            3'b001 : out <= in_a | in_b;      // or
            3'b111 : out <= (in_a < in_b) ? {{WIDTH-1{1'b0}}, 1'b1} : {WIDTH{1'b0}}; // less than
            default: out <= {WIDTH{1'b0}};
        endcase
    end



endmodule