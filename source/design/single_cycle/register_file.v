module register_file #(
    parameter ADDR_W = 5,
    parameter DATA_W = 32,
    parameter NREGS  = 32
) (
    input wire               clk,
    input wire               rst,
    input wire               we3,
    input wire  [ADDR_W-1:0] rd1,       // Source Register 1
    input wire  [ADDR_W-1:0] rd2,       // Source Register 2
    input wire  [ADDR_W-1:0] wa3,       // Destination Register
    input wire  [DATA_W-1:0] data_in,
    output wire [DATA_W-1:0] data_out1,
    output wire [DATA_W-1:0] data_out2 
);
    reg [DATA_W-1:0] regs [NREGS-1:0];
    integer i;
    
    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < NREGS; i = i +1) begin
                regs[i] <= {DATA_W{1'b0}};
            end
        end else if(we3)
            regs[wa3] <= data_in;
    end

    assign data_out1 = regs[rd1];
    assign data_out2 = regs[rd2];
endmodule