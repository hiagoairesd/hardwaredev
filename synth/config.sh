#!/usr/bin/env bash
#==============================================================================
# config.sh - Configuration loader for synthesis scripts
#
# This script loads configuration from .env file if it exists,
# or uses environment variables as fallback.
# This makes the project portable across different machines.
#==============================================================================

# Find the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Load .env file if it exists
if [[ -f "$ENV_FILE" ]]; then
    # Source the .env file, ignoring comments and empty lines
    set -a  # Mark all new variables for export
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        # Only set if not already set by environment
        if [[ -z "${!key}" ]]; then
            export "$key"="$value"
        fi
    done < "$ENV_FILE"
    set +a
fi

# =============================================================================
# Verify required paths and executables
# =============================================================================

# Check for required executables
YOSYS_BIN="${YOSYS_BIN:-yosys}"
NETLISTSVG_BIN="${NETLISTSVG_BIN:-netlistsvg}"

# Verify Yosys exists
if ! command -v "$YOSYS_BIN" &> /dev/null; then
    echo -e "\033[1;31mError: Yosys not found at '$YOSYS_BIN'\033[0m" >&2
    echo "Install Yosys or set YOSYS_BIN environment variable" >&2
    exit 1
fi

# Verify Netlistsvg exists (only needed for diagram generation)
if ! command -v "$NETLISTSVG_BIN" &> /dev/null; then
    echo -e "\033[1;33mWarning: netlistsvg not found at '$NETLISTSVG_BIN'\033[0m" >&2
    echo "Diagram generation will be skipped. Optional: Install netlistsvg or set NETLISTSVG_BIN" >&2
    NETLISTSVG_AVAILABLE=0
else
    NETLISTSVG_AVAILABLE=1
fi

# Best-effort Sky130 liberty auto-detection for specific synthesis.
# This keeps the flow portable when the PDK is installed locally but .env was
# left unset.
if [[ -z "${SKY130_LIB_PATH:-}" ]]; then
    for base in "$HOME/.volare" "$HOME/.ciel" /usr/share/pdk /usr/local/share/pdk /opt; do
        [[ -d "$base" ]] || continue
        SKY130_CANDIDATE=$(find "$base" -type f \( \
            -name 'sky130_fd_sc_hd__tt_100C_1v80.lib' -o \
            -name 'sky130_fd_sc_hd__tt_025C_1v80.lib' -o \
            -name 'sky130_fd_sc_hd*.lib' \
        \) -print -quit 2>/dev/null)
        if [[ -n "$SKY130_CANDIDATE" ]]; then
            export SKY130_LIB_PATH="$SKY130_CANDIDATE"
            break
        fi
    done
fi

# Verify project structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/../source"

# Handle both absolute and relative paths
if [[ "$SOURCE_DIR" = /* ]]; then
    ROOT="$SOURCE_DIR"
else
    ROOT="$(cd "$SCRIPT_DIR" && cd "$SOURCE_DIR" && pwd)"
fi

DESIGN_DIR="$ROOT/design"

if [[ ! -d "$DESIGN_DIR" ]]; then
    echo -e "\033[1;31mError: Design directory not found at $DESIGN_DIR\033[0m" >&2
    exit 1
fi

# Export verified paths
export PROJECT_ROOT
export SCRIPT_DIR
export ROOT
export DESIGN_DIR
export YOSYS_BIN
export NETLISTSVG_BIN
export NETLISTSVG_AVAILABLE
export SKY130_LIB_PATH
