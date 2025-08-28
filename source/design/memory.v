module memory #(
    parameter AWIDTH = 5,
    parameter DWIDTH = 8
) (
    input   wire                clk,
    input   wire                wr,
    input   wire                rd,
    input   wire [AWIDTH-1:0]   addr,
    inout   wire [DWIDTH-1:0]   data
);
    
    reg [DWIDTH-1 :0] mem [0:2**AWIDTH-1];

    always @(posedge clk) begin
        if(wr)
            mem[addr] <= data;
    end


    assign data= (rd)? mem[addr] : {DWIDTH{'bz}};

endmodule
