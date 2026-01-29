module reg_reset #(
    parameter WIDTH = 8,
    parameter NREGS = 4
) (
    output reg [WIDTH-1:0] regs [NREGS-1:0] 
);
    reg [WIDTH-1:0] regs [NREGS-1:0];
    integer i;

    always @* begin
        for (i = 0; i < NREGS; i = i +1) begin
            regs[i] = {WIDTH{1'b0}};
        end
    end
endmodule