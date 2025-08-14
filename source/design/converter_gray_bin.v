module converter_bin_gray #(
    parameter WIDTH = 4
) (
    input   [WIDTH-1:0] gray_in,
    output  [WIDTH-1:0] bin_out
);
    integer i;
    
    always @* begin
        bin_out[WIDTH-1] = gray_in[WIDTH-1];
        for(i = WIDTH-2; i >= 0; i = i -1) begin
            bin_out[i] = gray_in[i] ^ bin_out[i+1];
        end
    end
endmodule