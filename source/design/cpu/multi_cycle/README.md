# Multi-Cycle CPU

## Overview

Implementation of a 32-bit MIPS-like CPU with FSM-based multi-cycle control.
Instructions are split across multiple states, reusing the ALU and memory across different cycles.

## Design Files

Folder: [source/design/cpu/multi_cycle](.)

- `cpu_mc.v`: multi-cycle CPU top-level integration
- `control_unit_mc.v`: FSM-based control unit
- `memory.v`: unified memory (instruction + data)
- Reused common blocks from [source/design/cpu/common](../common):
  - `alu.v`
  - `register_file.v`

## Architecture Document

Full architectural description:
- [source/design/cpu/multi_cycle/ISA/ARCHITECTURE.md](ISA/ARCHITECTURE.md)

## Verification

Testbenches and test programs:
- Folder: [source/verif/cpu/multi_cycle](../../../verif/cpu/multi_cycle)
- Main files:
  - `cpu_mc_tb.sv`
  - `control_unit_tb.sv`
  - `memory_tb.sv`
  - `assembly/`
- Test guide:
  - [source/verif/cpu/multi_cycle/README.md](../../../verif/cpu/multi_cycle/README.md)

### CPU Test Suite (multi-cycle)

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
| 16 | `zero_register_protection` | Protect register zero from writes | R0 immutability |
| 17 | `halt_placement` | HALT in different control-flow points | Correct termination |
| 18 | `loop_counter` | Counter loop with branches | Iteration control correctness |
| 19 | `array_sum` | Accumulation over memory region | Load/accumulate/store integrity |
| 20 | `integration` | End-to-end integration scenario | Full datapath + control coverage |

## Simulation

From [simu](../../../../simu):

```bash
./simulate cpu_mc
./simulate cpu_mc +test=1
./simulate cpu_mc +test=1 +trace
./simulate cpu_mc +test=1 +trace_w
```

You can also run modules individually:

```bash
./simulate alu
./simulate control_unit_mc
./simulate register_file
./simulate memory
```

### Quick regression

```bash
cd ../../../../simu
for i in {1..20}; do
  echo "Running test $i"
  ./simulate cpu_mc +test=$i || exit 1
done
```

## Execution FSM (summary)

Main states:
- `FETCH`
- `DECODE`
- `MEM_ADR`
- `MEM_READ`
- `MEM_WRITEBACK`
- `MEM_WRITE`
- `EXECUTE`
- `ALU_WRITEBACK`
- `BRANCH`
- `EXECUTE_IMM`
- `IMM_WRITEBACK`
- `JUMP`
- `HALT`

Typical flows:
- R-type: `FETCH -> DECODE -> EXECUTE -> ALU_WRITEBACK`
- LW: `FETCH -> DECODE -> MEM_ADR -> MEM_READ -> MEM_WRITEBACK`
- SW: `FETCH -> DECODE -> MEM_ADR -> MEM_WRITE`

For control signal details (`IorD`, `PCSrc`, `PCEn`, `aluSrcA/B`, etc.), refer to the architecture document.
