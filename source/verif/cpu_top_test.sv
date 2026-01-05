`define ANSI_RED  "\033[31m"
`define ANSI_GRN  "\033[32m"
`define ANSI_BOLD "\033[1m"
`define ANSI_RST  "\033[0m"

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
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_reg(
        input int regnum,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got !== exp) begin
            $display({`ANSI_BOLD, `ANSI_RED, "\t\t TEST FAILED", `ANSI_RST});
            $display("\tAt time %0t", $time);
            $display("R%0d = %0d (0x%08h) | R%0d should be: %0d (0x%08h)",
                     regnum, got, got, regnum, exp, exp);
            $finish;
        end else begin
            $display("\tAt time %0t", $time);
            $display("R%0d = %0d (0x%08h) %sOK%s",
                     regnum, got, got, {`ANSI_BOLD, `ANSI_GRN}, `ANSI_RST);
        end
    endtask
    
    task automatic check;
        begin
            check_reg(1, DUT.rb_inst.regs[1], 32'd1);
            check_reg(2, DUT.rb_inst.regs[2], 32'd2);
            check_reg(3, DUT.rb_inst.regs[3], 32'd3);
        end
    endtask

    initial begin
        rst = 1'b1;
        #1;

        $readmemh("../source/verif/assembly/program.hex", DUT.instr_mem_inst.mem);

        repeat (2) @(posedge clk);

        rst = 1'b0;
        repeat (8) @(posedge clk);
        check();

        $display({`ANSI_BOLD, `ANSI_GRN, "\t\t TESTS PASSED", `ANSI_RST});
        $finish;
  end

    initial begin
        $dumpfile("cpu_top.vcd");
        $dumpvars(0, cpu_top_test);
    end
endmodule