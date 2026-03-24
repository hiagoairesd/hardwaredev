#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(realpath "$SCRIPT_DIR/../source")"

DESIGN="$ROOT/design"
CPU_DESIGN="$DESIGN/cpu"
VERIF="$ROOT/verif"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dut> [vvp_args...]" >&2
  exit 1
fi
dut="$1"
shift

out="${dut}.out"
tb="$(find "$VERIF" -type f -name "${dut}_tb.sv" -print -quit)"

echo "###############################################################"
echo "DUT : $dut"
echo "TB  : $tb"

rtl="$(find "$DESIGN" -type f \( -name "${dut}.v" -o -name "${dut}.sv" \) -print -quit)"

if [[ -z "$rtl" ]]; then
  echo "ERROR: RTL not found for DUT '$dut' under: $DESIGN" >&2
  exit 1
fi

if [[ -z "$tb" || ! -f "$tb" ]]; then
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

common_dirs=()
candidate_cpu_common="$(dirname "$rtl_dir")/common"
if [[ -d "$candidate_cpu_common" && "$candidate_cpu_common" != "$rtl_dir" ]]; then
  common_dirs+=("$candidate_cpu_common")
fi

for common_dir in "${common_dirs[@]}"; do
  common_srcs=(
    $(find "$common_dir" -type f \( -name '*.v' -o -name '*.sv' \) -print)
  )
  if [[ ${#common_srcs[@]} -gt 0 ]]; then
    design_srcs+=("${common_srcs[@]}")
  fi
done

iverilog_cmd=(
  iverilog -g2012 -o "$out"
  -y "$CPU_DESIGN"
  -y "$DESIGN"
  -y "$rtl_dir"
)

for common_dir in "${common_dirs[@]}"; do
  iverilog_cmd+=( -y "$common_dir" )
done

iverilog_cmd+=( "${design_srcs[@]}" "$tb" )

"${iverilog_cmd[@]}"

echo "###############################################################"
echo "### Running Simulation... #####################################"
echo "###############################################################"

vvp "$out" "$@" 2>&1 | \
  grep -v "VCD warning" | \
  grep -v "Not enough words in the file"

echo "### Finished Simulation #######################################"