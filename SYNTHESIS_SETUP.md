# Synthesis Setup Guide

This guide explains how to configure the synthesis scripts for your machine (local or in CI/CD).

## Prerequisites

Install required tools:

```bash
# Yosys (logic synthesis)
sudo apt-get install yosys

# Optional: netlistsvg (for schematic diagrams)
npm install -g netlistsvg

# Sky130 PDK (for technology-specific synthesis)
# Follow: https://silicon-compiler.readthedocs.io/en/latest/reference/install.html
```

## Configuration

### Option 1: Using `.env` file (Recommended for local development)

1. Copy the template:
```bash
cp .env.example .env
```

2. Edit `.env` and set your paths:
```bash
# Sky130 library path
SKY130_LIB_PATH=/path/to/sky130_fd_sc_hd__tt_100C_1v80.lib

# Optional: Custom tool paths
# YOSYS_BIN=/custom/path/yosys
# NETLISTSVG_BIN=/custom/path/netlistsvg
```

3. The `.env` file is **not** committed to git (see `.gitignore`)

### Option 2: Using Environment Variables

Set variables before running scripts:

```bash
export SKY130_LIB_PATH=/path/to/sky130_fd_sc_hd__tt_100C_1v80.lib
./synth/generic_synth.sh alu
```

### Option 3: CI/CD Pipeline

In GitHub Actions, GitLab CI, etc., set secrets/variables:

```yaml
# Example: GitHub Actions
env:
  SKY130_LIB_PATH: ${{ secrets.SKY130_LIB_PATH }}
```

## Usage

### Generic Synthesis (Technology Independent)

```bash
cd synth
./generic_synth.sh <module_name>
```

Example:
```bash
./generic_synth.sh alu              # Synthesize ALU
./generic_synth.sh control_unit     # Synthesize Control Unit
./generic_synth.sh registers_bank   # Synthesize Register Bank
```

Outputs:
- `<module>_generic_synth.v` - Gate-level netlist (technology independent)
- `<module>.json` - Netlist in JSON format
- `<module>.svg` - Schematic diagram (if netlistsvg installed)

### Specific Synthesis (Sky130 Technology Mapping)

Requires `SKY130_LIB_PATH` to be configured first!

```bash
cd synth
./specific_synth.sh <module_name>
```

Example:
```bash
./generic_synth.sh alu
./specific_synth.sh alu    # Technology mapping with Sky130
```

Outputs:
- `<module>_specific_synth.v` - Gate-level netlist with Sky130 cells
- Statistics report (area, timing)

## Troubleshooting

### Error: Yosys not found
```
Solution: Install yosys or set YOSYS_BIN=/path/to/yosys
```

### Error: SKY130_LIB_PATH is not set
```
Solution: Create .env file with SKY130_LIB_PATH=/path/to/library.lib
```

### Error: Sky130 library file not found
```
Solution: Verify the path exists and has read permissions
ls -l $SKY130_LIB_PATH
```

### Warning: netlistsvg not available
```
Solution: Optional - only needed for SVG diagrams
Install: npm install -g netlistsvg
Or: skip SVG generation (synthesis still works)
```

## Project Structure

```
hardwaredev/
├── .env                    # Local configuration (git-ignored)
├── .env.example            # Configuration template
├── synth/
│   ├── config.sh          # Configuration loader
│   ├── generic_synth.sh   # Generic synthesis script
│   └── specific_synth.sh  # Sky130 mapping script
└── source/
    └── design/
        └── single_cycle/  # Verilog designs
```

## For Open Source Contributors

1. Developers should **never commit** their local `.env` file
2. Contribute changes to `.env.example` if new variables are needed
3. Document new configuration variables in this guide
4. Use environment variables for CI/CD pipelines
5. Test with multiple paths to ensure portability
