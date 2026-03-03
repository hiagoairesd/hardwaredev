#!/usr/bin/env bash
set -eo pipefail

# ANSI color codes
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color (resets the color)

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Usage: $0 <top_module_name>${NC}" >&2
  exit 1
fi

DUT="$1"

# 1. Preparing the temporary script for Yosys
TMP_SCRIPT=$(mktemp)
echo "# Reading all design files" > "$TMP_SCRIPT"
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
write_verilog -noattr ${DUT}_generic_synth.v
write_json ${DUT}.json
EOF

# 2. Execute synthesis
echo "###############################################################"
echo -e "${BLUE}         --- Starting synthesis for module: $DUT ---${NC}"
echo "###############################################################"
"$YOSYS_BIN" -s "$TMP_SCRIPT"
rm "$TMP_SCRIPT"

# 3. Generate SVG and apply styling
if [[ $NETLISTSVG_AVAILABLE -eq 1 && -f "${DUT}.json" ]]; then
    echo "###############################################################"
    echo -e "${BLUE}          --- Generating SVG diagram for: $DUT ---${NC}"
    echo "###############################################################"
    
    "$NETLISTSVG_BIN" "${DUT}.json" -o "${DUT}.svg"
    
    sed -i '1a <style>svg { background-color: white; }</style>' "${DUT}.svg"
    
    echo -e "${GREEN}          --- Success! Diagram generated: ${DUT}.svg ---${NC}"
    echo "###############################################################"
elif [[ -f "${DUT}.json" ]]; then
    echo -e "${GREEN}Synthesis successful. JSON generated: ${DUT}.json${NC}"
    echo -e "${BLUE}Note: netlistsvg not available. Skipping SVG diagram generation.${NC}"
else
    echo -e "${RED}Error: The file ${DUT}.json was not generated. Please check the Yosys logs.${NC}"
    exit 1
fi