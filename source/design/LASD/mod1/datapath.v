module datapath#(
    parameter WIDTH = 8
) (
    input wire              clk,
    input wire              rst,
    input wire              wr,
    input wire [1:0]        wraddr,     // Write Address
    input wire [1:0]        rda1,       // Read Address 1
    input wire [1:0]        rda2,       // Read Address 2
    input wire [WIDTH-1:0]  data_in,
    output reg [WIDTH-1:0]  data_out1,
    output reg [WIDTH-1:0]  data_out2   
);
    reg [WIDTH-1:0] mem [3:0];

    always @(posedge clk) begin
        if(rst) begin
            mem[0] <= 8'b0;
            mem[1] <= 8'b0;
            mem[2] <= 8'b0;
            mem[3] <= 8'b0;
            
        end else if(wr)
            mem[wraddr] <= data_in;
    end

    assign data_out1 = mem[rda1];
    assign data_out2 = mem[rda2];

endmodule