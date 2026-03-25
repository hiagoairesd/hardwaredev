#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(realpath "$SCRIPT_DIR/../source")"

DESIGN="$ROOT/design"
CPU_DESIGN="$DESIGN/cpu"
VERIF="$ROOT/verif"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dut> [single_cycle|multi_cycle] [vvp_args...]" >&2
  echo "Aliases: <dut>_mc, <dut>_sc, <dut>_multi_cycle, <dut>_single_cycle" >&2
  exit 1
fi
dut="$1"
shift

alias_variant=""
if [[ "$dut" =~ ^(.+)_mc$ ]]; then
  dut="${BASH_REMATCH[1]}"
  alias_variant="multi_cycle"
elif [[ "$dut" =~ ^(.+)_sc$ ]]; then
  dut="${BASH_REMATCH[1]}"
  alias_variant="single_cycle"
elif [[ "$dut" =~ ^(.+)_multi_cycle$ ]]; then
  dut="${BASH_REMATCH[1]}"
  alias_variant="multi_cycle"
elif [[ "$dut" =~ ^(.+)_single_cycle$ ]]; then
  dut="${BASH_REMATCH[1]}"
  alias_variant="single_cycle"
fi

variant="$alias_variant"
if [[ $# -gt 0 && ( "$1" == "single_cycle" || "$1" == "multi_cycle" ) ]]; then
  variant="$1"
  shift
fi

variant_short=""
if [[ "$variant" == "single_cycle" ]]; then
  variant_short="sc"
elif [[ "$variant" == "multi_cycle" ]]; then
  variant_short="mc"
fi

if [[ -n "$variant" ]]; then
  if [[ -n "$variant_short" ]]; then
    out="${dut}_${variant_short}.out"
  else
    out="${dut}_${variant}.out"
  fi
else
  out="${dut}.out"
fi
if [[ -n "$variant" ]]; then
  tb="$(find "$VERIF" -type f -path "*/cpu/${variant}/${dut}_tb.sv" -print -quit)"
  if [[ -z "$tb" ]]; then
    tb="$(find "$VERIF" -type f -path "*/cpu/${variant}/${dut}_${variant}_tb.sv" -print -quit)"
  fi
  if [[ -z "$tb" && -n "$variant_short" ]]; then
    tb="$(find "$VERIF" -type f -path "*/cpu/${variant}/${dut}_${variant_short}_tb.sv" -print -quit)"
  fi
else
  tb="$(find "$VERIF" -type f -name "${dut}_tb.sv" -print -quit)"
fi

echo "###############################################################"
echo "DUT : $dut"
echo "TB  : $tb"

if [[ -n "$variant" ]]; then
  rtl="$(find "$DESIGN" -type f -path "*/cpu/${variant}/*" \( -name "${dut}.v" -o -name "${dut}.sv" \) -print -quit)"
  if [[ -z "$rtl" ]]; then
    rtl="$(find "$DESIGN" -type f -path "*/cpu/${variant}/*" \( -name "${dut}_${variant}.v" -o -name "${dut}_${variant}.sv" \) -print -quit)"
  fi
  if [[ -z "$rtl" && -n "$variant_short" ]]; then
    rtl="$(find "$DESIGN" -type f -path "*/cpu/${variant}/*" \( -name "${dut}_${variant_short}.v" -o -name "${dut}_${variant_short}.sv" \) -print -quit)"
  fi
else
  rtl="$(find "$DESIGN" -type f \( -name "${dut}.v" -o -name "${dut}.sv" \) -print -quit)"
fi

if [[ -z "$rtl" ]]; then
  if [[ -n "$variant" ]]; then
    echo "ERROR: RTL not found for DUT '$dut' under variant '$variant' in: $DESIGN" >&2
  else
    echo "ERROR: RTL not found for DUT '$dut' under: $DESIGN" >&2
  fi
  exit 1
fi

if [[ -z "$tb" || ! -f "$tb" ]]; then
  if [[ -n "$variant" ]]; then
    echo "ERROR: Testbench not found for DUT '$dut' under variant '$variant' in: $VERIF" >&2
  else
    echo "ERROR: Testbench not found: $tb" >&2
  fi
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