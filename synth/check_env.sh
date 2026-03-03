#!/usr/bin/env bash
#==============================================================================
# check_env.sh - Configuration health check script
#==============================================================================

# ANSI color codes
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========== Synthesis Configuration Health Check ==========${NC}"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "$SCRIPT_DIR/config.sh" 2>/dev/null; then
    echo -e "${RED}[FAIL] Failed to load config.sh${NC}"
    exit 1
fi

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo "Required Tools:"
if command -v "$YOSYS_BIN" &> /dev/null; then
    echo -e "${GREEN}[OK]${NC} Yosys: $(yosys --version | head -n1)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Yosys: NOT FOUND"
    ((FAILED++))
fi

if command -v "$NETLISTSVG_BIN" &> /dev/null; then
    echo -e "${GREEN}[OK]${NC} Netlistsvg: installed"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} Netlistsvg: NOT FOUND (optional)"
    ((WARNINGS++))
fi
echo

echo "Project Structure:"
if [[ -d "$DESIGN_DIR" ]]; then
    echo -e "${GREEN}[OK]${NC} Design directory: $DESIGN_DIR"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Design directory: NOT FOUND"
    ((FAILED++))
fi

if [[ -d "$DESIGN_DIR/single_cycle" ]]; then
    echo -e "${GREEN}[OK]${NC} Single-cycle designs found"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Single-cycle designs: NOT FOUND"
    ((FAILED++))
fi
echo

echo "Sky130 Technology (Optional):"
if [[ -n "$SKY130_LIB_PATH" && -f "$SKY130_LIB_PATH" ]]; then
    echo -e "${GREEN}[OK]${NC} SKY130_LIB_PATH configured"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} SKY130_LIB_PATH: NOT SET (optional)"
    ((WARNINGS++))
fi
echo

echo "=========================================="
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}Status: READY FOR SYNTHESIS${NC}"
    echo "Passed: $PASSED |  Warnings: $WARNINGS"
else
    echo -e "${RED}Status: CONFIGURATION ERROR${NC}"
    echo "Failed: $FAILED | Passed: $PASSED"
fi
echo "=========================================="
echo

exit $FAILED
