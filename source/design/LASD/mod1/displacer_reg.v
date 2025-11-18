module displacer_reg #(
    parameter WIDTH = 8
) (
    input wire             clk,
    input wire             clear,
    input wire             load,
    input wire             shift,
    input wire [WIDTH-1:0] data_in,
    output reg            carry,
    output reg [WIDTH-1:0] data_out
);

    always @(negedge clk) begin
        if(clear) begin
            data_out <= {(WIDTH){1'b0}};
            carry <= 1'b0;

        end else if(load) begin
            data_out <= data_in;
            
        end else if(shift) begin
            carry    <= data_out[0];
            data_out <= {data_out[0], data_out[WIDTH-1:1]};

        end
    end

endmodule