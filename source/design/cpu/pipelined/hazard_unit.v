module hazard_unit #(

)(
    input  wire       M_regWrite, W_regWrite, E_memtoReg,
    input  wire [4:0] D_rs, D_rt, E_rs, E_rt, M_wa3, W_wa3,
    output reg  [1:0] forwardA, forwardB,
    output reg        F_stall, D_stall, E_flush, PC_write
);
/* 
    The hazard detection unit receives the two source registers from the instruction in the Execute stage (E_rt and E_rt) 
    and the destination registers from the instructions in the Memory and Writeback stages (M_wa3 and W_wa3). 
    It also receives the RegWrite signals from the Memory and Writeback stages (M_regWrite and W_regWrite) 
    to know whether the destination register will actually be written.
*/
    always @* begin
        if ((E_rs != 1'b0) && (E_rs == M_wa3) && M_regWrite) begin
            forwardA = 2'b10; // Forward from Memory stage
        end else if((E_rs != 1'b0) && (E_rs == W_wa3) && W_regWrite) begin
            forwardA = 2'b01; // Forward from Writeback stage
        end else begin
            forwardA = 2'b00; // No hazard, use data from register file
        end

        if ((E_rt != 1'b0) && (E_rt == M_wa3) && M_regWrite) begin
            forwardB = 2'b10; // Forward from Memory stage
        end else if((E_rt != 1'b0) && (E_rt == W_wa3) && W_regWrite) begin
            forwardB = 2'b01; // Forward from Writeback stage
        end else begin
            forwardB = 2'b00; // No hazard, use data from register file
        end
    end


endmodule