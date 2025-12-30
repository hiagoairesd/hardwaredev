module control_unit #(
    parameter CTRL_WORD_W = 10,
    parameter INSTR_W = 32
) (
    input  wire [INSTR_W-1:0]      instr,
    output reg  [CTRL_WORD_W-1:0]  word
);

    wire [5:0] opcode = instr[31:26];
    wire [5:0] funct = instr[5:0];


    always @* begin
        case (opcode) 
            6'b000000: begin    // R-TYPE INSTRUCTION
                case (funct)
                    6'b100000: word = 10'b1100100000;   // ADD
                    6'b100010: word = 10'b1101100000;   // SUB
                    6'b100100: word = 10'b1100000000;   // AND
                    6'b100101: word = 10'b1100010000;   // OR
                    6'b101010: word = 10'b1101110000;   // SLT  (set on less than)
                    default:   word = 10'b0000000000;
                endcase
            end
            
            6'b100011: word = 10'b1010100010;   // LW   (load word)
            6'b101011: word = 10'b0x101001x0;   // SW   (store word)
            6'b000100: word = 10'b0x011010x0;   // BEQ  (branch if equal)
            6'b001000: word = 10'b1010100000;   // ADDi (add imm)
            6'b000010: word = 10'b0xxxxxxxx1;   // JMP  (jump)
            default:   word = 10'b0000000000;
        endcase
    end
endmodule
