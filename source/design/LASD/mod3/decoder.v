module decoder #(
    parameter CTRL_WIDTH = 10,
    parameter INSTR_WIDTH = 32
) (
    input  wire [INSTR_WIDTH-1:0] instr,
    output wire [CTRL_WIDTH-1:0]  word
);

    wire [0:5] opcode = [31:25] instr;
    wire [0:5] funct = [5:0] instr;


    always @*
        case (opcode) 
            6'b000000: begin    // R-TYPE INSTRUCTION
                case (funct)
                    6'b100000: word = 10'b1100100000;   // ADD
                    6'b100010: word = 10'b1101100000;   // SUB
                    6'b100100: word = 10'b1100000000;   // AND
                    6'b100101: word = 10'b1100010000;   // OR
                    6'b101010: word = 10'b1101110000;   // SLT
                endcase
            end
            
            6'b100011: word = 10'b1010100010;   // LW   (load word)
            6'b101011: word = 10'b0x101001x0;   // SW   (store word)
            6'b000100: word = 10'b0x011010x0;   // BEQ  (branch if equal)
            6'b001000: word = 10'b1010100000;   // ADDi (add imm)
            6'b000010: word = 10'b0xxxxxxxx1;   // JMP  (jump)
            default:   word = 10'bxxxxxxxxxx;
        endcase
endmodule
