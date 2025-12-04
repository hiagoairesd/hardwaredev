module fifo #(
    parameter AWIDTH = 5,
    parameter DWIDTH = 8
) (
    input   wire                 clk, 
    input   wire                 rst, 
    input   wire                 wr_en, 
    input   wire                 rd_en,
    input   wire [DWIDTH-1:0]    data_in,
    output  wire                 full, 
    output  wire                 empty, 
    output  reg  [DWIDTH-1:0]    data_out
);
    localparam DEPTH = 2 ** AWIDTH;
    reg [DWIDTH-1:0]    memory [0:DEPTH-1]; //register array
    reg [AWIDTH-1:0]    wptr;               //write pointer
    reg [AWIDTH-1:0]    rptr;               //read pointer
    reg                 wrote;              //control var

    // func code
    always @(posedge clk or posedge rst) begin
        if(rst) begin   //reset all control signals
            wptr  <= {(AWIDTH){1'b0}};  
            rptr  <= {(AWIDTH){1'b0}};
            wrote <= 1'b0;
        end else begin
            if (rd_en && !empty) begin
                data_out <= memory[rptr];   //load data from the current rptr location to data_out
                rptr     <= rptr + 1'b1;    //increments rptr to point the next address
                wrote    <= 1'b0;           //update last op to read
            end
            if (wr_en && !full) begin
                memory[wptr] <= data_in;        //store data_in to the location of current wptr
                wptr         <= wptr + 1'b1;    //increments wptr to point to the next address available
                wrote        <= 1'b1;           //update last op to write
            end
        end
    end

    // outputs
    assign empty = (wptr == rptr) && !wrote; // fifo is empty when wptr points to the same address as rptr and last op was read
    assign full  = (wptr == rptr) && wrote;  // fifo is full when wptr points to the same address as rptr and last op was write
endmodule