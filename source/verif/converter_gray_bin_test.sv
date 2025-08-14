`timescale 1ns/1ps

module tb_converter_gray_bin;

    parameter WIDTH = 4;

    reg  [WIDTH-1:0] gray_in;
    wire [WIDTH-1:0] bin_out;

    // Instancia o módulo que vamos testar
    converter_gray_bin #(
        .WIDTH(WIDTH)
    ) uut (
        .gray_in(gray_in),
        .bin_out(bin_out)
    );

    integer i;
    reg [WIDTH-1:0] bin_expected;

    initial begin
        $display("Gray -> Binário");
        $display("----------------");

        // Testa todos os códigos Gray possíveis
        for (i = 0; i < (1 << WIDTH); i = i + 1) begin
            gray_in = i[WIDTH-1:0]; // atribui um valor de Gray qualquer

            // Aguarda propagação
            #1;

            // Converte Gray manualmente para comparação
            bin_expected[WIDTH-1] = gray_in[WIDTH-1];
            for (integer j = WIDTH-2; j >= 0; j = j - 1) begin
                bin_expected[j] = bin_expected[j+1] ^ gray_in[j];
            end

            // Mostra resultado
            $display("Gray: %b  ->  Binário calculado: %b  |  Esperado: %b", 
                      gray_in, bin_out, bin_expected);

            // Verifica se bate
            if (bin_out !== bin_expected) begin
                $display("ERRO! Conversão incorreta para Gray %b", gray_in);
                $stop;
            end
        end

        $display("TEST PASSED");
        $finish;
    end
endmodule
