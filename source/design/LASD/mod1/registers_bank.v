module registers_bank#(
    parameter DATA_W = 8,
    parameter NREGS = 4
) (
    input wire              clk,
    input wire              rst,
    input wire              wr,
    input wire [1:0]        wraddr,     // Write Address
    input wire [1:0]        rda1,       // Read Address 1
    input wire [1:0]        rda2,       // Read Address 2
    input wire [DATA_W-1:0]  data_in,
    output wire [DATA_W-1:0]  data_out1,
    output wire [DATA_W-1:0]  data_out2   
);
    reg [DATA_W-1:0] regs [NREGS:0];
    integer i;

    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < NREGS; i = i +1) begin
                regs[i] <= {DATA_W{1'b0}};
            end
            
        end else if(wr)
            regs[wraddr] <= data_in;
    end

    assign data_out1 = regs[rda1];
    assign data_out2 = regs[rda2];

endmodule