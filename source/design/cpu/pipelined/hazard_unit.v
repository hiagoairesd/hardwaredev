module hazard_unit #(

)(
    input  wire       M_regWrite, W_regWrite, E_memtoReg,
    input  wire [4:0] D_rs, D_rt, E_rs, E_rt, 
    input  wire [4:0] M_wa3, W_wa3,                         // wa3 == WriteReg (write RF address pipelined from E stage to M and W stages)
    output reg  [1:0] forwardA, forwardB,
    output reg        F_stall, D_stall, E_flush
);
/* 
    The hazard detection unit receives the two source registers from the instruction in the Execute stage (E_rs and E_rt) 
    and the destination registers from the instructions in the Memory and Writeback stages (M_wa3 and W_wa3). 
    It also receives the RegWrite signals from the Memory and Writeback stages (M_regWrite and W_regWrite) 
    to know whether the destination register will actually be written.
    M_regWrite
*/
    always @* begin
    //==============================================================================
    // 1) forwardA logic
    //==============================================================================

        //-------------------------------------------------------------------------
        // Forward from Memory stage
        //-------------------------------------------------------------------------

        // if the source register of the instruction in the Execute stage (E_rs) matches the destination register of the instruction in the Memory stage (M_wa3) and the Memory stage instruction is writing to a register (M_regWrite),
        // then we have a data hazard. In this case, we need to forward the data from the Memory stage to the Execute stage.

        if ((E_rs != 1'b0) && (E_rs == M_wa3) && M_regWrite) begin
            forwardA = 2'b10; 
        end

        //-------------------------------------------------------------------------
        // Forward from Writeback stage
        //-------------------------------------------------------------------------

        // if the source register of the instruction in the Execute stage (E_rs) matches the destination register of the instruction in the Writeback stage (W_wa3) and the Writeback stage instruction is writing to a register (W_regWrite),
        // then we have a data hazard. In this case, we need to forward the data from the Writeback stage to the Execute stage.

        else if((E_rs != 1'b0) && (E_rs == W_wa3) && W_regWrite) begin
            forwardA = 2'b01; 
        end 

        //-------------------------------------------------------------------------
        // No hazard, use data from register file
        //-------------------------------------------------------------------------

        else begin
            forwardA = 2'b00; // No hazard, use data from register file
        end

    //==============================================================================
    // 2) forwardB logic
    //==============================================================================
        // The logic for forwardB is similar to forwardA, but it checks the second source register (E_rt) instead of the first (E_rs).
        
        //-------------------------------------------------------------------------
        // Forward from Memory stage
        //-------------------------------------------------------------------------

        if ((E_rt != 1'b0) && (E_rt == M_wa3) && M_regWrite) begin
            forwardB = 2'b10;
        end

        //-------------------------------------------------------------------------
        // Forward from Writeback stage
        //-------------------------------------------------------------------------

        else if((E_rt != 1'b0) && (E_rt == W_wa3) && W_regWrite) begin
            forwardB = 2'b01;
        end

        //-------------------------------------------------------------------------
        // No hazard, use data from register file
        //-------------------------------------------------------------------------

        else begin
            forwardB = 2'b00; // No hazard, use data from register file
        end

    //==============================================================================
    // Load-use hazard detection (Stall logic)
    //==============================================================================
        // If E_memtoReg is true, it means that the instruction in the Execute stage is a load instruction (LW).
        // If the destination register of this load instruction (E_rt) matches either of the source registers of the instruction in the Decode stage (D_rs or D_rt), 
        // then we have a load-use hazard. In this case, we need to stall the pipeline to allow the load instruction to complete and write its result back to the register file before the dependent instruction in the Decode stage can proceed.
        F_stall = 1'b0;
        D_stall = 1'b0;
        E_flush = 1'b0;

        if(E_memtoReg && ((E_rt == D_rs) || (E_rt == D_rt))) begin
            F_stall = 1'b1; 
            D_stall = 1'b1;
            E_flush = 1'b1;
        end
    end
endmodule
