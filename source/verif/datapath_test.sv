module datapath_test();

    // input declarations
    logic clock = 0;
    logic reset = 1;

    logic       wr;
    logic [1:0] wraddr; 
    logic [1:0] rda1;
    logic [1:0] rda2;
    logic [7:0] data_in;

    // output declarations
    wire [7:0] data_out1;
    wire [7:0] data_out2;

    // clock generation
    initial begin
        forever begin
            #5 clock = ~clock;
        end
    end

    initial begin
        #10 reset = 0;
    end

    datapath DUT(
        .clk        (clock),
        .rst        (reset),
        .wr         (wr),
        .wraddr     (wraddr),
        .rda1       (rda1),
        .rda2       (rda2),
        .data_in    (data_in),
        .data_out1  (data_out1),
        .data_out2 (data_out2)
    );

    initial begin
        #10
        wr = 1'b1; wraddr = 2'b00 ; rda1 = 2'b00; rda2 = 2'b01; data_in= 8'b10101010;
        #10
        wr = 1'b1; wraddr = 2'b01 ; rda1 = 2'b10; rda2 = 2'b01; data_in= 8'b11110000;
        #10
        wr = 1'b1; wraddr = 2'b10 ; rda1 = 2'b10; rda2 = 2'b01; data_in= 8'b00001111;
        #10
        wr = 1'b0; wraddr = 2'b11 ; rda1 = 2'b11; rda2 = 2'b01; data_in= 8'b01010101;
    end

    initial begin
        $monitor("time: %0d \t rst= %b \n wr= %b \t wraddr= %b \t rda1= %b \t rda2= %b \t data_in= %b \n data_out1= %b \t data_out2= %b",
                $time, reset, wr, wraddr, rda1, rda2, data_in, data_out1, data_out2);
    end

    initial begin
        #100 $finish;
    end
    
endmodule