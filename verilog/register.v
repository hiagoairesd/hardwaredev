module register #(
    parameter WIDTH = 8
) (
    input       [WIDTH-1:0]   data_in,
    input                     load,
    input                     clk,
    input                     rst,
    output  reg [WIDTH-1:0]   data_out
);

always @(posedge clk) begin
    if(rst) data_out <= {WIDTH{1'b0}};
    else if(load) data_out <= data_in;
end
endmodule
