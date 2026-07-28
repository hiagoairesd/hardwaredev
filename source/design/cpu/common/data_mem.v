module data_mem #(
    parameter ADDR_W = 5,
    parameter DATA_W = 32,
    parameter DEPTH  = 256
) (
    input   wire                clk,
    input   wire                we,
    input   wire [ADDR_W-1:0]   addr,
    input   wire [DATA_W-1:0]   data_in,
    output  wire [DATA_W-1:0]   data_out
);
    reg [DATA_W-1 :0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i +1) begin
            mem[i] = {DATA_W{1'b0}};
        end
    end

    always @(posedge clk) begin
        if(we)
            mem[addr] <= data_in;
    end
    assign data_out = mem[addr];
endmodule
