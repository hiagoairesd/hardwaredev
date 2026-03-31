# Single-Cycle CPU

## Overview

Implementation of a 32-bit MIPS-like CPU with a single-cycle datapath.
Each instruction is executed in a single clock cycle (fetch, decode, execute, memory, and write-back in the same combinational cycle).

## Design Files

Folder: [source/design/cpu/single_cycle](.)

- `cpu_sc.v`: single-cycle CPU top-level integration
- `instr_mem.v`: instruction memory
- `data_mem.v`: data memory
- Reused common blocks from [source/design/cpu/common](../common):
  - `alu.v`
  - `control_unit.v`: shared single-cycle instruction decode and control logic
  - `register_file.v`: shared register bank (`DATA_W` is parameterized; the current architectural organization remains 32 registers with 5-bit register addresses)

## Architecture Document

Full architectural description:
- [source/design/cpu/single_cycle/ISA/ARCHITECTURE.md](ISA/ARCHITECTURE.md)

## Verification

Testbenches and test programs:
- Folder: [source/verif/cpu/single_cycle](../../../verif/cpu/single_cycle)
- Main files:
  - `cpu_sc_tb.sv`
  - `control_unit_tb.sv`
  - `instr_mem_tb.sv`
  - `data_mem_tb.sv`
  - `assembly/`
- Test guide:
  - [source/verif/cpu/single_cycle/README.md](../../../verif/cpu/single_cycle/README.md)

### CPU Test Suite (single-cycle)

| Test ID | Name | Description | Key Validation |
|--------|------|-------------|----------------|
| 1 | `regs` | Basic register write operations | R1=1, R2=2, R3=3 |
| 2 | `basic_swlw` | Store/Load word integration | SW/LW addressing |
| 3 | `border_swlw` | Edge case signed immediates | Sign-extension, memory limit |
| 4 | `rtype` | R-type ALU operations | ALU results |
| 5 | `jump` | Jump instruction control flow | Jump taken, PC update |
| 6 | `beq` | Branch-if-equal and loop behavior | BEQ taken/not-taken |
| 7 | `andi` | AND-immediate (zero-extension) | Immediate extension policy |
| 8 | `ori` | OR-immediate (zero-extension) | Immediate extension policy |
| 9 | `lui` | Load upper immediate | Upper 16-bit placement |
| 10 | `sll` | Shift left logical | Shift amount handling |
| 11 | `srl` | Shift right logical | Shift result correctness |
| 12 | `bne` | Branch-if-not-equal | BNE taken/not-taken |
| 13 | `blt` | Branch-if-less-than (signed) | Signed comparison |
| 14 | `fibonacci` | Fibonacci sequence program | Loop/control/data-path integration |
| 15 | `fibonacci_overflow` | Fibonacci with 32-bit overflow | Wrap-around behavior |

## Simulation

From [simu](../../../../simu):

```bash
./simulate cpu_sc
./simulate cpu_sc +test=1
./simulate cpu_sc +test=1 +trace
./simulate cpu_sc +test=1 +trace_w
```

You can also run modules individually:

```bash
./simulate alu
./simulate control_unit
./simulate register_file
```

### Quick regression

```bash
cd ../../../../simu
for i in {1..15}; do
  echo "Running test $i"
  ./simulate cpu_sc +test=$i || exit 1
done
```

## ISA Scope (summary)

- R-Type: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`
- I-Type: `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`, `BEQ`, `BNE`, `BLT`
- J-Type: `JUMP`
- System: `HALT`

For encoding details, immediate handling policy, PC flow, and architectural contracts, refer to the architecture document.
