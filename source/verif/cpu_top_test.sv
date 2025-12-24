module cpu_top_test();

    localparam ADDR_W = 8;
    localparam DATA_W = 32;

    reg clk;
    reg rst;

    cpu_top
    #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) DUT (
        .clk(clk)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // clock generation
    always #5 clk =~clk;
    
    initial begin
        $dumpfile("cpu_top.vcd");
        $dumpvars(0, cpu_top_test);

        rst = 1'b1;
        #50;
        rst = 1'b0;

        #200 rst = 1'b1;
        $display("Smoke test OK: cpu_top compiled and simulated.");
        $finish;
    end
endmodule