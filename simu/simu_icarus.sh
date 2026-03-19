#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(realpath "$SCRIPT_DIR/../source")"

DESIGN="$ROOT/design"
VERIF="$ROOT/verif"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dut> [vvp_args...]" >&2
  exit 1
fi
dut="$1"
shift

out="${dut}.out"
tb="${VERIF}/${dut}_tb.sv"

echo "###############################################################"
echo "DUT : $dut"
echo "TB  : $tb"

rtl="$(find "$DESIGN" -type f \( -name "${dut}.v" -o -name "${dut}.sv" \) -print -quit)"

if [[ -z "$rtl" ]]; then
  echo "ERROR: RTL not found for DUT '$dut' under: $DESIGN" >&2
  exit 1
fi

if [[ ! -f "$tb" ]]; then
  echo "ERROR: Testbench not found: $tb" >&2
  exit 1
fi

echo "RTL : $rtl"
echo "###############################################################"
echo "### Running Compilation and Elaboration... ####################"
echo "###############################################################"

# Collect all RTL sources for the DUT by searching in the same directory where
# the DUT file lives (e.g., single_cycle/ or multi_cycle/).
# This avoids pulling in conflicting duplicate module definitions from other
# subdirectories (practices/, multi_cycle/, etc.).
rtl_dir="$(dirname "$rtl")"
design_srcs=(
  $(find "$rtl_dir" -type f \( -name '*.v' -o -name '*.sv' \) -print)
)

iverilog -g2012 -o "$out" \
    -y "$DESIGN" \
    -y "$rtl_dir" \
    "${design_srcs[@]}" \
    "$tb"

echo "###############################################################"
echo "### Running Simulation... #####################################"
echo "###############################################################"

vvp "$out" "$@" 2>&1 | \
  grep -v "VCD warning" | \
  grep -v "Not enough words in the file"

echo "### Finished Simulation #######################################"