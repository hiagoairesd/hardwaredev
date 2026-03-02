lea#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(realpath "$SCRIPT_DIR/../source")"
DESIGN_DIR="$ROOT/design"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <nome_do_top_module>" >&2
  exit 1
fi

DUT="$1"
RTL_TOP="$(find "$DESIGN_DIR" -type f \( -name "${DUT}.v" -o -name "${DUT}.sv" \) -print -quit)"

TMP_SCRIPT=$(mktemp)

echo "# Lendo todos os arquivos de design" > "$TMP_SCRIPT"
find "$DESIGN_DIR/single_cycle" -type f \( -name "*.v" -o -name "*.sv" \) | while read -r file; do
  echo "read_verilog -sv \"$file\"" >> "$TMP_SCRIPT"
done

cat <<EOF >> "$TMP_SCRIPT"
hierarchy -top $DUT -check
proc
flatten
techmap
opt_clean -purge
write_json ${DUT}.json
write_verilog ${DUT}_synth.v
check
stat
EOF

echo "--- Iniciando síntese do módulo: $DUT ---"
yosys -s "$TMP_SCRIPT"
rm "$TMP_SCRIPT"