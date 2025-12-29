module data_mem #(
    parameter ADDR_W = 5,
    parameter DATA_W = 32
) (
    input   wire                clk,
    input   wire                wr,
    input   wire                rd,
    input   wire [ADDR_W-1:0]   addr,
    inout   wire [DATA_W-1:0]   data
);
    
    reg [DATA_W-1 :0] mem [0:2**ADDR_W-1];

    always @(posedge clk) begin
        if(wr)
            mem[addr] <= data;
    end


    assign data= (rd)? mem[addr] : {DATA_W{1'bz}};

endmodule
