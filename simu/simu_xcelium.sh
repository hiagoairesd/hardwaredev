#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/hiago/Dev/hardwaredev/source"
DESIGN="$ROOT/design"
VERIF="$ROOT/verif"
LASD="$DESIGN/LASD"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dut> [xrun_args...]" >&2
  exit 1
fi
dut="$1"
shift

tb="${VERIF}/${dut}_test.sv"

deps=(
  "$LASD/mod1/registers_bank.v"
  "$LASD/mod2/alu.v"
  "$LASD/mod3/data_mem.v"
  "$LASD/mod3/instr_mem.v"
  "$LASD/mod3/instr_mem.v"
  "$LASD/mod3/control_unit.v"
)

echo "###############################################################"
echo "DUT : $dut"
echo "TB  : $tb"

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
echo "### Compilation + Elaboration + Simulation starting... ########"
echo "###############################################################"

srcs=()
if [[ "$dut" == "cpu_top" ]]; then
  echo "MODE: cpu_top (with deps)"
  srcs+=( "$rtl" "${deps[@]}" "$tb" )
else
  echo "MODE: single-module (no deps)"
  srcs+=( "$rtl" "$tb" )
fi

xrun -access +rwc \
  "${srcs[@]}" \
  -input ./simu.tcl \
  "$@"

echo "### Finished Simulation #######################################"