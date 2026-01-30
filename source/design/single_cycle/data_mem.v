module data_mem #(
    parameter ADDR_W = 5,
    parameter DATA_W = 32
) (
    input   wire                clk,
    input   wire                we,
    input   wire [ADDR_W-1:0]   addr,
    inout   wire [DATA_W-1:0]   data
);
    reg [DATA_W-1 :0] mem [0:2**ADDR_W-1];
    
    integer i;
    initial begin
        for (i = 0; i < 2**ADDR_W; i = i +1) begin
            mem[i] = {DATA_W{1'b0}};
        end
    end

    always @(posedge clk) begin
        if(we)
            mem[addr] <= data;
    end
    assign data = (we == 1'b0)? mem[addr] : {DATA_W{1'bz}};
endmodule
