module counter #(
    parameter WIDTH = 5
)(
    input   wire             clk,
    input   wire             load,
    input   wire             enab,
    input   wire             rst,
    input   wire [WIDTH-1:0] cnt_in,
    output  reg  [WIDTH-1:0] cnt_out
);

    always @(posedge clk)
    begin
        if(rst)
            cnt_out <= {WIDTH{1'b0}};
        else begin 
            if(load)
                cnt_out <= cnt_in;
            else if(enab)
                cnt_out <= cnt_out + 1'b1;     
        end
    end

endmodule
