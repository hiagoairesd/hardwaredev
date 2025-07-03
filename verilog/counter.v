module counter #(
    parameter WIDTH = 5
)(
    input               clk,
    input               load,
    input               enab,
    input               rst,
    input       [WIDTH-1:0] cnt_in,
    output  reg [WIDTH-1:0] cnt_out
);

    always @(posedge clk)begin
        if(rst)
            cnt_out <= {WIDTH{1'b0}};
        else begin 
            if(load)
                cnt_out <= cnt_in;
            else if(enab)
                cnt_out <= cnt_out + 1;
            
        end
    end

endmodule
