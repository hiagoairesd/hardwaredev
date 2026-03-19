module register_file_tb();

    localparam DATA_W = 32;
    localparam NREGS = 32;
    localparam int REG_ADDR_W = $clog2(NREGS);

    // input declarations
    logic clk = 0;
    logic rst = 1;

    logic       we3;
    logic [REG_ADDR_W-1:0] rd1;
    logic [REG_ADDR_W-1:0] rd2;
    logic [REG_ADDR_W-1:0] wa3;
    logic [DATA_W-1:0] data_in;

    // output declarations
    wire [DATA_W-1:0] data_out1;
    wire [DATA_W-1:0] data_out2;
    
    // clock generation
    always #5 clk = ~clk;

    initial begin
        #10 rst = 0;
    end

    register_file # (
        .ADDR_W(REG_ADDR_W),
        .DATA_W(DATA_W),
        .NREGS (NREGS)
    ) register_file (
        .clk        (clk),
        .rst        (rst),
        .we3        (we3),
        .rd1        (rd1),
        .rd2        (rd2),
        .wa3        (wa3),
        .data_in    (data_in),
        .data_out1  (data_out1),
        .data_out2  (data_out2)
    );

    initial begin
        #10
        we3 = 1'b1; wa3 = 5'd0; rd1 = 5'd0; rd2 = 5'd1; data_in = 32'hAAAAAAAA;
        #10
        we3 = 1'b1; wa3 = 5'd1; rd1 = 5'd2; rd2 = 5'd1; data_in = 32'hF0F0F0F0;
        #10
        we3 = 1'b1; wa3 = 5'd2; rd1 = 5'd2; rd2 = 5'd1; data_in = 32'h0F0F0F0F;
        #10
        we3 = 1'b0; wa3 = 5'd3; rd1 = 5'd3; rd2 = 5'd1; data_in = 32'h55555555;
    end

    initial begin
        $monitor("time: %0d \t rst= %b \n we3= %b \t wa3= %b \t rd1= %b \t rd2= %b \t data_in= %b \n data_out1= %b \t data_out2= %b",
                $time, rst, we3, wa3, rd1, rd2, data_in, data_out1, data_out2);
    end

    initial begin
        #100 $finish;
    end

    initial begin
        $dumpfile("register_file.vcd");
        $dumpvars(0, register_file_tb);
    end
    
endmodule