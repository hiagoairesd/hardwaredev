module converter_bin_gray #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] bin_in,
    output wire [WIDTH-1:0] gray_out
);
    assign gray_out = bin_in ^ (bin_in >> 1'b1);

endmodule