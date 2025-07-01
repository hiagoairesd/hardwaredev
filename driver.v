module driver #(
    parameter WIDTH = 8
) (
    input       [WIDTH-1:0] data_in,
    input                   data_en,
    output  reg [WIDTH-1:0] data_out
);
    
   // assign data_out = (data_en == 1)? data_in : 8'hzz;

   always @*
   begin
        data_out = 8'hzz;

        if (data_en == 1) data_out = data_in;

        
   end

endmodule