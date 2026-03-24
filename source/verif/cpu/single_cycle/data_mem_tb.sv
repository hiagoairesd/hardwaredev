module data_mem_tb();

    localparam ADDR_W = 5;
    localparam DATA_W = 32;

    // input declarations
    logic clk = 0;
    logic we;
    logic [ADDR_W-1:0] addr;
    wire [DATA_W-1:0] data;
    reg [DATA_W-1:0] data_drive;

    assign data = we ? data_drive : {DATA_W{1'bz}};

    // clock generation
    always #5 clk = ~clk;

    data_mem # (
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) data_mem (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .data (data)
    );

    task check;
        input [DATA_W-1:0] exp_data;
        if(data !== exp_data) begin
            $display("TEST FAILED");
            $display("At time %0d \nwe = %b \t addr = %b \t data = %h",
                        $time, we, addr, data);
            $display("'data' should be: %h", exp_data);
            $finish;
        end
        else begin 
            $display ("At time %0d \nwe = %b \t addr = %b \t data = %h OK",
                        $time, we, addr, data);
        end
    endtask

    initial begin
        #10
        // Write to address 0
        we = 1'b1; addr = 5'd0; data_drive = 32'hAAAAAAAA;
        #10
        // Write to address 1
        we = 1'b1; addr = 5'd1; data_drive = 32'hF0F0F0F0;
        #10
        // Write to address 2
        we = 1'b1; addr = 5'd2; data_drive = 32'h0F0F0F0F;
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