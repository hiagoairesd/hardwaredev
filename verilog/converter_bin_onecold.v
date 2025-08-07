module converter_bin_onecold #(
    parameter WIDTH = 4
) (
    input   [WIDTH-1:0]     bin_in,
    output  [(1 << WIDTH)-1:0]  onecold_out // (1<<WIDTH) == 2**WIDTH
);
    onecold_out = {(1 << WIDTH){1'b1}};

    assign onecold_out[bin_in] = 1'b0;

endmodule