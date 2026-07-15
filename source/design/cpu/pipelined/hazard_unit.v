module hazard_unit (
    input  wire       D_branch, E_regWrite, E_memtoReg, M_regWrite, W_regWrite, M_memtoReg,
    input  wire [4:0] D_rs, D_rt, E_rs, E_rt, 
    input  wire [4:0] M_wa3, W_wa3, E_wa3,       // wa3 == WriteReg (write RF address pipelined from E stage to M and W stages)
    output reg  [1:0] forwardAE, forwardBE,
    output reg        forwardAD, forwardBD,
    output reg        F_stall, D_stall, E_flush
);
    wire lw_stall;
    wire branch_stall;
/* 
    The hazard detection unit receives the two source registers from the instruction in the Execute stage (E_rs and E_rt) 
    and the destination registers from the instructions in the Memory and Writeback stages (M_wa3 and W_wa3). 
    It also receives the RegWrite signals from the Memory and Writeback stages (M_regWrite and W_regWrite) 
    to know whether the destination register will actually be written.
*/
//==============================================================================
// Forwarding logic
//==============================================================================

    always @* begin
    //==============================================================================
    // 1) ForwardA to Execute Stage
    //==============================================================================

        //-------------------------------------------------------------------------
        // From Memory stage
        //-------------------------------------------------------------------------

        // if the source register of the instruction in the Execute stage (E_rs) matches the destination register of the instruction in the Memory stage (M_wa3) and the Memory stage instruction is writing to a register (M_regWrite),
        // then we have a data hazard. In this case, we need to forward the data from the Memory stage to the Execute stage.

        if ((E_rs != 1'b0) && (E_rs == M_wa3) && M_regWrite) begin
            forwardAE = 2'b10; 
        end

        //-------------------------------------------------------------------------
        // From Writeback stage
        //-------------------------------------------------------------------------

        // if the source register of the instruction in the Execute stage (E_rs) matches the destination register of the instruction in the Writeback stage (W_wa3) and the Writeback stage instruction is writing to a register (W_regWrite),
        // then we have a data hazard. In this case, we need to forward the data from the Writeback stage to the Execute stage.

        else if((E_rs != 1'b0) && (E_rs == W_wa3) && W_regWrite) begin
            forwardAE = 2'b01; 
        end 

        //-------------------------------------------------------------------------
        // No hazard, use data from register file
        //-------------------------------------------------------------------------

        else begin
            forwardAE = 2'b00; // No hazard, use data from register file
        end
    
    //==============================================================================
    // 2) ForwardA to Decode Stage (from Memory stage)
    //==============================================================================
        // The logic for forwardAD is similar to forwardAE, but it checks the source register of the instruction in the Decode stage (D_rs) instead of the Execute stage (E_rs).

        if(((D_rs != 0) && (D_rs == M_wa3)) && M_regWrite) begin
            forwardAD = 1'b1;
        end else begin
            forwardAD = 1'b0;
        end
    
    //==============================================================================
    // 3) ForwardB to Execute Stage logic
    //==============================================================================
        // The logic for forwardBE is similar to forwardAE, but it checks the second source register (E_rt) instead of the first (E_rs).
        
        //-------------------------------------------------------------------------
        // Forward from Memory stage
        //-------------------------------------------------------------------------

        if ((E_rt != 1'b0) && (E_rt == M_wa3) && M_regWrite) begin
            forwardBE = 2'b10;
        end

        //-------------------------------------------------------------------------
        // Forward from Writeback stage
        //-------------------------------------------------------------------------

        else if((E_rt != 1'b0) && (E_rt == W_wa3) && W_regWrite) begin
            forwardBE = 2'b01;
        end

        //-------------------------------------------------------------------------
        // No hazard, use data from register file
        //-------------------------------------------------------------------------

        else begin
            forwardBE = 2'b00; // No hazard, use data from register file
        end

    //==============================================================================
    // 4) ForwardB to Decode Stage (from Memory stage)
    //==============================================================================
    // The logic for forwardBD is similar to forwardBE, but it checks the second source register of the instruction in the Decode stage (D_rt) instead of the Execute stage (E_rt).

        if(((D_rt != 0) && (D_rt == M_wa3)) && M_regWrite) begin
            forwardBD = 1'b1;
        end else begin
            forwardBD = 1'b0;
        end
    end

//==============================================================================
// Load-use hazard detection (Stall logic)
//==============================================================================
    // Load-Word Stall logic
    /*
        If E_memtoReg is true, it means that the instruction in the Execute stage is a load instruction (LW).
        If the destination register of this load instruction (E_rt) matches either of the source registers of the instruction in the Decode stage (D_rs or D_rt), 
        then we have a load-use hazard. In this case, we need to stall the pipeline to allow the load instruction to complete and write its result back to the register file before the dependent instruction in the Decode stage can proceed.
    */
    assign lw_stall = E_memtoReg && ((E_rt == D_rs) || (E_rt == D_rt));
    //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Branch Stall logic
    /*
        If D_branch is true, it means that the instruction in the Decode stage is a branch instruction.
        If the destination register of the instruction in the Execute stage (E_wa3) or the Memory stage (M_wa3) matches either of the source registers of the branch instruction (D_rs or D_rt), 
        and the instruction in the Execute stage is writing to a register (E_regWrite) or the instruction in the Memory stage is a load instruction (M_memtoReg), then we have a branch hazard. 
        In this case, we need to stall the pipeline to allow the branch instruction to resolve its condition before proceeding with the next instruction.
    */
    assign branch_stall = (D_branch && E_regWrite && ((E_wa3 == D_rs) || (E_wa3 == D_rt))) || (D_branch && M_memtoReg && ((M_wa3 == D_rs) || (M_wa3 == D_rt)));
    
    //-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    always @* begin
        if(lw_stall || branch_stall) begin
            F_stall = 1'b1; 
            D_stall = 1'b1;
            E_flush = 1'b1;
        end else begin
            F_stall = 1'b0;
            D_stall = 1'b0;
            E_flush = 1'b0;
        end
    end
endmodule
