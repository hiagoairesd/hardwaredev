module converter_bin_onehot #(
    parameter WIDTH = 4
) (
    input   [WIDTH-1:0]     bin_in,
    output  [(2**WIDTH)-1:0]  onehot_out
);
    assign onehot_out = 1'b1 << (bin_in);
    
/*
    always @*
    begin
        onehot_out[bin_in] = 1'b1;
    end
*/
endmodule