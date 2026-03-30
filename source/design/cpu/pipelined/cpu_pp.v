module cpu_pp #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int DEPTH  = 256
)(
    input wire clk,
    input  wire rst,
    output wire halted
);
    wire halt;
    assign halted = halt;
    reg [ADDR_W-1:0] pc;

//==============================================================================
// 1) PC Logic
//==============================================================================
    reg  [ADDR_W-1:0] pc;
    wire [ADDR_W-1:0] pc_next;      // Next PC value after selection logic
    wire [ADDR_W-1:0] PCJump;       // Jump target address for J-type instructions

    assign PCJump  = {pc[ADDR_W-1:ADDR_W-4], addr, 2'b00};    // Jump target address for J-type instructions
    assign pc_next = 
        (PCSrc == 2'b00) ? alu_out :   
        (PCSrc == 2'b01) ? alu_reg :
        (PCSrc == 2'b10) ? PCJump  : alu_out;

    // PC update policy:
    //   - reset forces PC=0
    //   - when halt is asserted, PC stops updating (freezes at current value)
    always @(posedge clk) begin
        if (rst)
            pc <= {ADDR_W{1'b0}};
        else if (!halt)
            pc <= pc_next;
    end

//==============================================================================
// )
//==============================================================================
    wire [4:0] wa3 = (regDst) ? rd : rt;

    wire [DATA_W-1:0] rf_data_out1;     // Data from rs register
    wire [DATA_W-1:0] rf_data_out2;     // Data from rt register
    wire [DATA_W-1:0] rf_wdata;
    
    register_file #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .NREGS  (NREGS)
    ) register_file (
        .clk        (clk),
        .rst        (rst),
        .we3        (regWrite),
        .rd1        (rs),           //A1
        .rd2        (rt),           //A2   
        .wa3        (wa3),          //A3
        .data_in    (rf_wdata),
        .data_out1  (rf_data_out1),
        .data_out2  (rf_data_out2)
    );

    // Writeback:
    //   - memtoReg=1 selects dm_data (load)
    //   - memtoReg=0 selects alu_out
    assign rf_wdata = (memtoReg)? dm_data : alu_out;

//==============================================================================
// )
//==============================================================================

    intr_mem #(
        .ADDR_W  (ADDR_W),
        .INSTR_W (INSTR_W),
        .DEPTH   (DEPTH)
    ) instr_mem (
        .addr_in   (pc),
        .instr_out (instr)
    );

//==============================================================================
// )
//==============================================================================

    data_mem #(
        .ADDR_W(ADDR_W)
    ) data_mem (
        .clk  (clk),
        .we   (memWrite),
        .addr (alu_out),
        .data (dm_data)
    );


//==============================================================================
// )
//==============================================================================
    reg [DATA_W-1:0] instr;       // Instruction register

endmodule