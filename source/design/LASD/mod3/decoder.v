module decoder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] inst,
    output wire [9:0]       word
);
    assign word = inst[9:0];
endmodule
