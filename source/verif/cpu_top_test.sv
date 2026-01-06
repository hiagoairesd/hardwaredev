`define ANSI_RED  "\033[31m"
`define ANSI_GRN  "\033[32m"
`define ANSI_BOLD "\033[1m"
`define ANSI_RST  "\033[0m"

module cpu_top_test();
    localparam ADDR_W = 8;
    localparam DATA_W = 32;

    reg clk;
    reg rst;

    string testname;
    string prog_file;
    int cycles;

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

    task automatic pick_test(input string name);
        begin
            unique case(name)
                "regs": begin
                    prog_file = "../source/verif/assembly/regs.hex";
                    cycles= 9;
                end
                "basic_swlw": begin
                    prog_file = "../source/verif/assembly/basic_swlw.hex";
                    cycles= 9;
                end
                "border_swlw": begin
                    prog_file = "../source/verif/assembly/border_swlw.hex";
                    cycles= 15;
                end
                "rtype": begin
                    prog_file = "../source/verif/assembly/rtype.hex";
                    cycles= 14;
                end
                "jump": begin
                    prog_file = "../source/verif/assembly/jump.hex";
                    cycles= 11;
                end
                "beq": begin
                    prog_file = "../source/verif/assembly/beq.hex";
                    cycles= 16;
                end
                "integration": begin
                    prog_file = "../source/verif/assembly/basic_swlw.hex";
                    cycles= 21;
                end
                default: begin
                    $display("Unknown +test=%s", name);
                    $finish;
                end
            endcase
        end
    endtask

    task automatic check_regs;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd1);
            check(2, DUT.rb_inst.regs[2], 32'd2);
            check(3, DUT.rb_inst.regs[3], 32'd3);
        end
    endtask
    
    task automatic check_basic_swlw;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd42);
            check(0, DUT.data_mem_inst.mem[0], 32'd42);
            check(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    task automatic check_border_swlw;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd32767);
            check(2, DUT.rb_inst.regs[2], 32'd-32768);
            check(3, DUT.rb_inst.regs[3], 32'd-1);
            check(0, DUT.data_mem_inst.mem[0], 32'd-1);
            check(4, DUT.rb_inst.regs[4], 32'd-1);
            check(5, DUT.rb_inst.regs[5], 32'd0);
        end
    endtask
    //-------------------------------- CONTINUAR ABAIXO
    task automatic check_rtype;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd42);
            check(0, DUT.data_mem_inst.mem[0], 32'd42);
            check(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    task automatic check_jump;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd42);
            check(0, DUT.data_mem_inst.mem[0], 32'd42);
            check(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    task automatic check_beq;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd42);
            check(0, DUT.data_mem_inst.mem[0], 32'd42);
            check(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask

    task automatic check_integration;
        begin
            check(1, DUT.rb_inst.regs[1], 32'd42);
            check(0, DUT.data_mem_inst.mem[0], 32'd42);
            check(2, DUT.rb_inst.regs[2], 32'd42);
        end
    endtask






















    task automatic check(
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
    


    initial begin
        rst = 1'b1;
        #1;

        $readmemh("../source/verif/assembly/basic_swlw.hex", DUT.instr_mem_inst.mem);

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
        $dumpvars(0, DUT.data_mem_inst.mem[0]);
        $dumpvars(0, DUT.rb_inst.regs[1]);
        $dumpvars(0, DUT.rb_inst.regs[2]);
    end
endmodule