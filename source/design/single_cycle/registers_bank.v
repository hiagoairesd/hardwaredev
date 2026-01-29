module registers_bank#(
    parameter DATA_W = 32,
    parameter NREGS = 32,
    localparam int REG_W = $clog2(NREGS)
) (
    input wire                clk,
    input wire                rst,
    input wire                wr,
    input wire  [REG_W-1:0]   rd,        // Destination Register 
    input wire  [REG_W-1:0]   rs1,       // Source Register 1
    input wire  [REG_W-1:0]   rs2,       // Source Register 2
    input wire  [DATA_W-1:0]  data_in,
    output wire [DATA_W-1:0]  data_out1,
    output wire [DATA_W-1:0]  data_out2   
);
    reg [DATA_W-1:0] regs [NREGS-1:0];
    integer i;

    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < NREGS; i = i +1) begin
                regs[i] <= {DATA_W{1'b0}};
            end
        end else if(wr)
            regs[rd] <= data_in;
    end

    assign data_out1 = regs[rs1];
    assign data_out2 = regs[rs2];

endmodule