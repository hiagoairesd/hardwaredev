module data_mem_tb();

    localparam ADDR_W = 5;
    localparam DATA_W = 32;

    // input declarations
    reg clk;
    reg we;
    reg  [ADDR_W-1:0] addr;
    reg  [DATA_W-1:0] data_in;
    wire [DATA_W-1:0] data_out;
    

    // clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    data_mem # (
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem (
        .clk      (clk),
        .we       (we),
        .addr     (addr),
        .data_in  (data_in),
        .data_out (data_out)
    );

    task check;
        input [DATA_W-1:0] exp_data;
        if(data_out !== exp_data) begin
            $display("TEST FAILED");
            $display("At time %0d \nwe = %b \t addr = %b \t data_out = %h",
                        $time, we, addr, data_out);
            $display("'data_out' should be: %h", exp_data);
            $finish;
        end
        else begin 
            $display ("At time %0d \nwe = %b \t addr = %b \t data_out = %h OK",
                        $time, we, addr, data_out);
        end
    endtask

    initial begin
        #10
        // Write to address 0
        we = 1'b1; addr = 5'd0; data_in = 32'hAAAAAAAA;
        #10
        // Write to address 1
        we = 1'b1; addr = 5'd1; data_in = 32'hF0F0F0F0;
        #10
        // Write to address 2
        we = 1'b1; addr = 5'd2; data_in = 32'h0F0F0F0F;
        #10
        // Read from address 0
        we = 1'b0; addr = 5'd0; #1 check(32'hAAAAAAAA);
        #10
        // Read from address 1
        we = 1'b0; addr = 5'd1; #1 check(32'hF0F0F0F0);
        #10
        // Read from address 2
        we = 1'b0; addr = 5'd2; #1 check(32'h0F0F0F0F);
        #10
        // Read from uninitialized address 3
        we = 1'b0; addr = 5'd3; #1 check(32'h00000000);
        #10
        $display("TEST PASSED");
        $finish;
    end

    initial begin
        $dumpfile("data_mem.vcd");
        $dumpvars(0, data_mem_tb);
    end
    
endmodule