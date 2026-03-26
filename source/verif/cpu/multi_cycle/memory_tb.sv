`define ANSI_RED  "\033[31m"
`define ANSI_GRN  "\033[32m"
`define ANSI_BOLD "\033[1m"
`define ANSI_RST  "\033[0m"

module memory_tb();
    localparam ADDR_W = 8;
    localparam DATA_W = 32;

    reg clk;
    reg we;
    reg [ADDR_W-1:0] addr;
    reg [DATA_W-1:0] data_in;
    wire[DATA_W-1:0] data_out;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("memory.vcd");
        $dumpvars(0, memory_tb);
    end

    memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) DUT (
        .clk     (clk),
        .we      (we),
        .addr    (addr),
        .data_in (data_in),
        .data_out(data_out)
    );

    task automatic check(
        input int addr,
        input logic [DATA_W-1:0] got,
        input logic [DATA_W-1:0] exp
    );
        if (got !== exp) begin
            $display({`ANSI_BOLD, `ANSI_RED, "\t\t TEST FAILED", `ANSI_RST});
            $display("\tAt time %0t", $time);
            $display("MEM[%0d] = %0d (0x%08h) | MEM[%0d] should be: %0d (0x%08h)",
                     addr, got, got, addr, exp, exp);
            $finish;
        end else begin
            $display("\tAt time %0t", $time);
            $display("MEM[%0d] = %0d (0x%08h) %sOK%s",
                     addr, got, got, {`ANSI_BOLD, `ANSI_GRN}, `ANSI_RST);
        end
    endtask

    task automatic check_instr_segment;
        begin
            $display({`ANSI_BOLD, "\tINSTRUCTIONS TESTS", `ANSI_RST});
            $readmemh("../source/verif/cpu/multi_cycle/assembly/memoryTest.hex", DUT.mem);
            #10
            check(0, DUT.mem[0], 32'h8C080020);
            check(1, DUT.mem[1], 32'h21080001);
            check(2, DUT.mem[2], 32'hAC080020);
            check(3, DUT.mem[3], 32'h08000006);
            check(4, DUT.mem[4], 32'h00000000);
            check(5, DUT.mem[5], 32'h0000002A);
            check(6, DUT.mem[6], 32'hFC000000);
        end
    endtask

    task automatic check_data_segment;
        begin
            $display({`ANSI_BOLD, "\tDATA TESTS", `ANSI_RST});
            we      = 1'b0;
            addr    = '0;
            data_in = '0;

            // --- Test 1: Simple write then read back ---
            $display("\t  [1] Simple write/read");
            we = 1'b1; addr = 8'h80; data_in = 32'hDEADBEEF;
            @(posedge clk); #1;
            we = 1'b0;
            check(8'h80, data_out, 32'hDEADBEEF);

            // --- Test 2: Multiple positions written sequentially ---
            $display("\t  [2] Multiple positions");
            we = 1'b1;
            addr = 8'h81; data_in = 32'h00000001; @(posedge clk); #1;
            addr = 8'h82; data_in = 32'h00000002; @(posedge clk); #1;
            addr = 8'h83; data_in = 32'h00000004; @(posedge clk); #1;
            we = 1'b0;
            addr = 8'h81; #1; check(8'h81, data_out, 32'h00000001);
            addr = 8'h82; #1; check(8'h82, data_out, 32'h00000002);
            addr = 8'h83; #1; check(8'h83, data_out, 32'h00000004);

            // --- Test 3: Boundary – max address (0xFF) ---
            $display("\t  [3] Max address (0xFF)");
            we = 1'b1; addr = 8'hFF; data_in = 32'hCAFEBABE;
            @(posedge clk); #1;
            we = 1'b0;
            check(8'hFF, data_out, 32'hCAFEBABE);

            // --- Test 4: Overwrite same address ---
            $display("\t  [4] Overwrite same address");
            we = 1'b1; addr = 8'h84; data_in = 32'hAAAAAAAA;
            @(posedge clk); #1;
            data_in = 32'h55555555;
            @(posedge clk); #1;
            we = 1'b0;
            check(8'h84, data_out, 32'h55555555);

            // --- Test 5: we=0 must NOT write (value preserved) ---
            $display("\t  [5] Write disabled (we=0) preserves old value");
            we = 1'b1; addr = 8'h85; data_in = 32'h12345678;
            @(posedge clk); #1;
            we = 1'b0; data_in = 32'hFFFFFFFF;
            @(posedge clk); #1;
            check(8'h85, data_out, 32'h12345678);
        end
    endtask

    initial begin
        check_instr_segment();
        check_data_segment();
        $write({`ANSI_BOLD, "------- "});
        $write({`ANSI_BOLD, `ANSI_GRN, "TESTS PASSED", `ANSI_RST});
        $display({`ANSI_BOLD, " -------"});
        $finish;
    end
endmodule