#!/bin/bash
set -eo pipefail

# ANSI color codes
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color (resets the color)

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DUT=$1

if [[ -z "$DUT" ]]; then
  echo -e "${RED}Error: No module name provided!${NC}" >&2
  echo -e "${RED}Usage: $0 <top_module_name>${NC}" >&2
  exit 1
fi

# Check if Sky130 library path is configured
if [[ -z "$SKY130_LIB_PATH" ]]; then
  echo -e "${RED}Error: SKY130_LIB_PATH is not set!${NC}" >&2
  echo -e "${RED}Configure it in one of the following ways:${NC}" >&2
  echo -e "  1. Create .env file in project root (copy from .env.example)" >&2
  echo -e "  2. Set environment variable: export SKY130_LIB_PATH=/path/to/lib${NC}" >&2
  exit 1
fi

# Verify library file exists
if [[ ! -f "$SKY130_LIB_PATH" ]]; then
  echo -e "${RED}Error: Sky130 library file not found at:${NC}" >&2
  echo -e "  $SKY130_LIB_PATH" >&2
  exit 1
fi

LIB_FILE="$SKY130_LIB_PATH"
OUT_VERILOG="${DUT}_specific_synth.v"
SCRIPT_FILE="synth.ys"

# Generate Yosys script file
cat <<EOF > "$SCRIPT_FILE"
read_verilog ${DUT}_generic_synth.v
hierarchy -top $DUT
synth -top $DUT
dfflibmap -liberty $LIB_FILE
abc -liberty $LIB_FILE
opt_clean -purge
write_verilog $OUT_VERILOG
stat -liberty $LIB_FILE
EOF

# Execute Yosys filtering unwanted warnings
# '2>&1' redirects stderr to stdout
# grep -v filters out unwanted lines
echo "###############################################################"
echo -e "${BLUE}   --- Starting specific synthesis for module: $DUT ---${NC}"
echo "###############################################################"
"$YOSYS_BIN" -s "$SCRIPT_FILE" 2>&1 | grep -vE "Warning: Found unsupported expression|skipped.*without logic function|skipped sequential cell|skipped three-state cell"

echo "###############################################################"
echo -e "${GREEN}   --- Synthesis completed for $DUT! ---${NC}"
echo -e "${GREEN}   --- Output file: $OUT_VERILOG ---${NC}"
echo "###############################################################"

# Cleanup
rm -f "$SCRIPT_FILE"