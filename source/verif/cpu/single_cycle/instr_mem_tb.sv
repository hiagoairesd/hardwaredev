module instr_mem_tb();

    localparam ADDR_W = 8;
    localparam INSTR_W = 32;
    localparam DEPTH = 256;

    reg  [ADDR_W-1:0] addr_in_tb;
    wire [INSTR_W-1:0] instr_out_tb;

    instr_mem #(
        .ADDR_W(ADDR_W),
        .INSTR_W(INSTR_W),
        .DEPTH(DEPTH)
    ) DUT (
        .addr_in(addr_in_tb),
        .instr_out(instr_out_tb)
    );

    task check;
        input [INSTR_W-1:0] exp_instr;
        if(instr_out_tb !== exp_instr) begin
            $display("\nTEST FAILED");
            $display("At time \n%0d addr_in = %b instr_out = %h", $time, addr_in_tb, instr_out_tb);
            $display("'instr_out' should be: %h\n", exp_instr);
            $finish;
        end
        else begin
            $display("At time \n%0d addr_in = %b instr_out = %h OK", $time, addr_in_tb, instr_out_tb);
        end
    endtask

    initial begin
        $readmemh("../source/verif/cpu/assembly/basic_swlw.hex", DUT.mem); 
    end

    initial begin
        addr_in_tb = 8'd0;   #10 check(32'h2001002a);
        addr_in_tb = 8'd1;   #10 check(32'hac010000);
        addr_in_tb = 8'd2;   #10 check(32'h8c020000);
        addr_in_tb = 8'd3;   #10 check(32'hFC000000);
        addr_in_tb = 8'd10;  #10 check(32'd0); 
        addr_in_tb = 8'd150; #10 check(32'd0);
        $display("\t TEST PASSED");
        $finish;
    end

    initial begin
        $dumpfile("instr_mem.vcd");
        $dumpvars(0, instr_mem_tb);
    end

endmodule