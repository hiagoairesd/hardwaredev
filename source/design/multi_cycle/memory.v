module memory #(
    parameter WIDTH  = 32
)(
    input wire             clk,
    input wire             we,
    input wire [WIDTH-1:0] addr,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);
    reg [WIDTH-1 :0] mem [0:2**WIDTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < 2**WIDTH; i = i +1) begin
            mem[i] = {WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        if(we)
            mem[addr] <= data_in;
    end

    assign data_out = (we == 1'b0)? mem[addr] : {WIDTH{1'bz}};
endmodule