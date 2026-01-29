module cpu_top(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    input wire clk,
    input wire rst

);
    //==============================================================================
    // 1) Local parameters (ISA constants / widths)
    //==============================================================================



    //==============================================================================
    // 2) Architectural state (PC)
    //==============================================================================

    reg [ADDR_W-1:0] pc;

    always @(posedge clk) begin
        if(rst)
            pc <= {ADDR_W{1'b0}};
    end

    //==============================================================================
    // 2) Non-Architectural Instruction Register logic
    //==============================================================================

    reg [DATA_W-1:0] ir;
    wire IRWrite;

    always @(posedge clk) begin
        if (rst)
            ir <= {DATA_W{1'b0}};
        else if (IRWrite)
            ir <= instr;
    end

    //==============================================================================
    // 3) Control signals
    //==============================================================================
    
    wire [DATA_W-1:0] instr = mem_out; // instruction fetched from memory

    wire        regWrite;
    wire        regDst;
    wire        aluSrc;
    wire [2:0]  aluControl;
    wire        branch;
    wire        memWrite;
    wire        memtoReg;
    wire        jump;

    //==============================================================================
    // 3) Memory
    //==============================================================================

    reg  [ADDR_W-1:0] mem_addr = pc; // nem sempre recebe pc,   |falta terminar de implementar
    wire [DATA_W-1:0] mem_out;       // data read from memory   | falta terminar de implementar
    wire [DATA_W-1:0] mem_data_in;   // data to write to memory | falta terminar de implementar
    
    memory #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W)
    ) memory_inst (
        .clk(clk),
        .we(memWrite),
        .addr(mem_addr),
        .data_in(mem_data_in),
        .data_out(mem_out)
    );

    //==============================================================================
    // 8) PC next logic (pc_plus1 / branch / jump selection)
    //==============================================================================


    

endmodule