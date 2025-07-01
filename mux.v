module multiplexor #(
    parameter WIDTH = 5
) (
    input       [WIDTH-1:0] in0,
    input       [WIDTH-1:0] in1,
    input                   sel,
    output reg  [WIDTH-1:0] mux_out
);

    always @*
    begin
        if(sel == 1)
            mux_out = in1;
        else
            mux_out = in0;

    end

    /* or
    assign mux_out = (sel == 1)? in1 : in0;
    */

endmodule

