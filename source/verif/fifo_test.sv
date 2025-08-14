module fifo_test;

    // local constants
    localparam AWIDTH = 8;
    localparam DWIDTH = 5;
    localparam DEPTH  = 2 ** AWIDTH;

    // variables for FIFO inputs
    reg [DWIDTH-1:0] data_in;
    reg clk, wr_en, rd_en, rst;

    // nets for FIFO outputs
    wire full;
    wire empty;
    wire [DWIDTH-1:0] data_out;

    // FIFO instatiation
    fifo
    #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH)
    )
    fifo_dut(
        .data_in (data_in),
        .data_out(data_out),
        .clk     (clk),
        .rst     (rst),
        .wr_en   (wr_en),
        .rd_en   (rd_en),
        .full    (full),
        .empty   (empty)
    );

    // Stimulus for reading

    initial begin
        $monitorb("%d", $time,, clk,, rst,, wr_en,, rd_en,, data_in,, full,, empty,, data_out); // set up monitor for signal value change
        clk = 0; wr_en = 0; rd_en = 0; rst = 0; data_in =-1;    // initialize
        @(negedge clk) rst = 1;                                 // assert reset
        @(negedge clk) rst = 0;                                 // deassert reset
        @(negedge clk) wr_en  = 1;                                 // wr_en signal is made high to write data_in to FIFO
        @(negedge clk) begin
            wr_en = 0;              
            rd_en = 1;               //rd_en is asserted so that data previously written to the FIFO can be read
        end
        @(negedge clk) begin
            rd_en = 0;
            wr_en = 1;              //wr_en is asserted so that data can be written to the FIFO
        end
        repeat (DEPTH-1) @(negedge clk) data_in = data_in -1;
        @(negedge clk) begin        // repeat loop is added to write the data_in content for (2 ** AWIDTH-1)
            wr_en = 0;              // times, full signal can be seen high in the last clock pulse
            rd_en = 1;
        end
        repeat (DEPTH+1) @(negedge clk);    // rd_en is asserted and kept high for (2** AWIDTH+1) clocks
        $stop;                              // for reading of FIFO, empty signal can be seen high in the last clock pause
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, fifo_test);
    end
always #10 clk =~clk;
endmodule


