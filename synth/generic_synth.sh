#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(realpath "$SCRIPT_DIR/../source")"
DESIGN_DIR="$ROOT/design"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <nome_do_top_module>" >&2
  exit 1
fi

DUT="$1"

# 1. Preparação do script temporário do Yosys
TMP_SCRIPT=$(mktemp)

echo "# Lendo todos os arquivos de design" > "$TMP_SCRIPT"
find "$DESIGN_DIR/single_cycle" -type f \( -name "*.v" -o -name "*.sv" \) | while read -r file; do
  echo "read_verilog -sv \"$file\"" >> "$TMP_SCRIPT"
done

cat <<EOF >> "$TMP_SCRIPT"
hierarchy -top $DUT -check
proc
flatten
opt
techmap
abc -g AND,OR,XOR,MUX
opt_clean -purge
write_json ${DUT}.json
EOF

# 2. Executa a síntese
echo "--- Iniciando síntese do módulo: $DUT ---"
yosys -s "$TMP_SCRIPT"
rm "$TMP_SCRIPT"

# 3. Gera o SVG e aplica as correções automaticamente
if [ -f "${DUT}.json" ]; then
    echo "--- Gerando diagrama SVG para: $DUT ---"
    
    # Executa o netlistsvg
    netlistsvg "${DUT}.json" -o "${DUT}.svg"
    
    sed -i '1a <style>svg { background-color: white; }</style>' "${DUT}.svg"
    
    echo "Sucesso! Diagrama gerado: ${DUT}.svg"
else
    echo "Erro: O arquivo ${DUT}.json não foi gerado. Verifique os logs do Yosys."
    exit 1
fi