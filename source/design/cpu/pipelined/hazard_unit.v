module hazard_unit #(

)(
    input  wire       M_regWrite, W_regWrite,
    input  wire [4:0] E_rs, E_rt, M_wa3, W_wa3,
    output wire [1:0] BE_forward, AE_forward,
    output reg        stall
);

/* 
    The hazard detection unit receives the two source registers from the instruction in the Execute stage (E_rs and E_rt) 
    and the destination registers from the instructions in the Memory and Writeback stages (M_wa3 and W_wa3). 
    It also receives the RegWrite signals from the Memory and Writeback stages (M_regWrite and W_regWrite) 
    to know whether the destination register will actually be written.
*/

endmodule