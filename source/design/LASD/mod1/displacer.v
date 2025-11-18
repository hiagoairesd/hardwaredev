module displacer #(
    parameter WIDTH = 8
)(
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    wire shifted;

    assign shifted = in[WIDTH-1];
    assign out     = {in[WIDTH-2:0], shifted};
    
endmodule