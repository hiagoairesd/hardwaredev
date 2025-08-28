module controller (    
    input   wire [2:0]   opcode,
    input   wire [2:0]   phase,
    input   wire         zero,
    output  reg          sel,
                         rd,
                         ld_ir,
                         halt,
                         inc_pc,
                         ld_ac,
                         ld_pc,
                         wr,
                         data_e
);

wire  aluop, skz, jmp, sto, hlt;
assign aluop = (opcode == 3'b010)? 1'b1:
               (opcode == 3'b011)? 1'b1:
               (opcode == 3'b100)? 1'b1: 
               (opcode == 3'b101)? 1'b1:
                                   1'b0;

                                
assign skz =   (opcode == 3'b001)? 1'b1 : 1'b0;
assign jmp =   (opcode == 3'b111)? 1'b1 : 1'b0;
assign sto =   (opcode == 3'b110)? 1'b1 : 1'b0;
assign hlt =   (opcode == 3'b000)? 1'b1 : 1'b0;


always @* 
    begin
        case(phase)
        3'b000 : 
        begin
            sel    = 1'b1;
            rd     = 1'b0;
            ld_ir  = 1'b0;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b001 :
        begin
            sel    = 1'b1;
            rd     = 1'b1;
            ld_ir  = 1'b0;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b010 :
        begin
            sel    = 1'b1;
            rd     = 1'b1;
            ld_ir  = 1'b1;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b011 :
        begin
            sel    = 1'b1;
            rd     = 1'b1;
            ld_ir  = 1'b1;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b100 :
        begin
            sel    = 1'b0;
            rd     = 1'b0;
            ld_ir  = 1'b0;
            halt   = (hlt)? 1'b1 : 1'b0;
            inc_pc = 1'b1;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b101 :
        begin
            sel    = 1'b0;
            rd     = (aluop)? 1'b1 : 1'b0;
            ld_ir  = 1'b0;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = 1'b0;
            wr     = 1'b0;
            data_e = 1'b0;
        end
        3'b110 :
        begin
            sel    = 1'b0;
            rd     = (aluop)      ? 1'b1 : 1'b0;
            ld_ir  = 1'b0;
            halt   = 1'b0;
            inc_pc = (skz && zero)? 1'b1 : 1'b0;
            ld_ac  = 1'b0;
            ld_pc  = (jmp)        ? 1'b1 : 1'b0;
            wr     = 1'b0;        
            data_e = (sto)        ? 1'b1 : 1'b0;
        end
        3'b111 :
        begin
            sel    = 1'b0;
            rd     = (aluop)? 1'b1 : 1'b0;
            ld_ir  = 1'b0;
            halt   = 1'b0;
            inc_pc = 1'b0;
            ld_ac  = (aluop)? 1'b1 : 1'b0;
            ld_pc  = (jmp)  ? 1'b1 : 1'b0;
            wr     = (sto)  ? 1'b1 : 1'b0;
            data_e = (sto)  ? 1'b1 : 1'b0;
        end
        endcase
    
    end
    
endmodule
