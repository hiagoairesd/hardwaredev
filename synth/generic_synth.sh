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

# 1. Locate the DUT in the current design tree and gather its sources.
# Prefer matches under the CPU hierarchy when duplicate filenames exist elsewhere
# in the repository (for example, `memory.v` exists in both `practices/` and
# `cpu/multi_cycle/`).
mapfile -t RTL_MATCHES < <(find "$DESIGN_DIR" -type f \( -name "${DUT}.v" -o -name "${DUT}.sv" \) | sort)

if [[ ${#RTL_MATCHES[@]} -eq 0 ]]; then
  echo -e "${RED}Error: Could not find RTL source for module '$DUT' under $DESIGN_DIR${NC}" >&2
  exit 1
fi

RTL_FILE=""
for candidate in "${RTL_MATCHES[@]}"; do
  if [[ "$candidate" == */cpu/* ]]; then
    RTL_FILE="$candidate"
    break
  fi
done

if [[ -z "$RTL_FILE" ]]; then
  RTL_FILE="${RTL_MATCHES[0]}"
fi

if [[ ${#RTL_MATCHES[@]} -gt 1 ]]; then
  echo -e "${BLUE}Info: multiple RTL matches found for '$DUT'; using:${NC} $RTL_FILE"
fi

RTL_DIR="$(dirname "$RTL_FILE")"
CPU_COMMON_DIR="$(dirname "$RTL_DIR")/common"

TMP_SCRIPT=$(mktemp)
echo "# Reading design files for $DUT" > "$TMP_SCRIPT"

find "$RTL_DIR" -type f \( -name "*.v" -o -name "*.sv" \) | sort | while read -r file; do
  echo "read_verilog -sv -DSYNTHESIS \"$file\"" >> "$TMP_SCRIPT"
done

if [[ -d "$CPU_COMMON_DIR" && "$CPU_COMMON_DIR" != "$RTL_DIR" ]]; then
  find "$CPU_COMMON_DIR" -type f \( -name "*.v" -o -name "*.sv" \) | sort | while read -r file; do
    echo "read_verilog -sv -DSYNTHESIS \"$file\"" >> "$TMP_SCRIPT"
  done
fi

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
echo -e "${BLUE}         --- RTL directory: $RTL_DIR ---${NC}"
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