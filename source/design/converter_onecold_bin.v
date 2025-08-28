module converter_onecold_bin (
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0]         onecold_in,
    output reg  [$clog2(WIDTH)-1:0] bin_out
);

    integer i;
    always @* begin
        bin_out = {($clog2(WIDTH)){1'b0}};
        for (i = WIDTH-1; i >= 0; i = i -1;) begin
            if(!onecold_in[i])
                bin_out = i;
        end
    end
endmodule