#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/hiago/Dev/hardwaredev/source"
DESIGN="$ROOT/design"
VERIF="$ROOT/verif"
LASD="$DESIGN/LASD"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dut> [vvp_args...]" >&2
  exit 1
fi
dut="$1"
shift

out="${dut}.out"
tb="${VERIF}/${dut}_test.sv"

deps=(
  "$LASD/mod1/registers_bank.v"
  "$LASD/mod2/alu.v"
  "$LASD/mod3/data_mem.v"
  "$LASD/mod3/instr_mem.v"
  "$LASD/mod3/control_unit.v"
)

echo "###############################################################"
echo "DUT : $dut"
echo "TB  : $tb"

# Seache RTL file in design/ 
rtl="$(
  find "$DESIGN" -type f \( -name "${dut}.v" -o -name "${dut}.sv" \) 2>/dev/null \
  | head -n 1 || true
)"

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
echo "### Running Compilation and Elaboration...#####################"
echo "###############################################################"

if [[ "$dut" == "cpu_top" ]]; then
  echo "MODE: cpu_top (with deps)"
  iverilog -g2012 -o "$out" \
    "$rtl" \
    "${deps[@]}" \
    "$tb"
else
  echo "MODE: single-module (no deps)"
  iverilog -g2012 -o "$out" \
    "$rtl" \
    "$tb"
fi

echo "###############################################################"
echo "### Running Simulation... #####################################"
echo "###############################################################"

vvp "$out" "$@" 2>&1 | \
  grep -v "VCD warning" | \
  grep -v "Not enough words in the file"

echo "### Finished Simulation #######################################"