# Single-Cycle MIPS-like CPU Architecture
## Introduction
The objective of this document is to describe the architecture and design decisions of our 32-bit MIPS-like single-cycle processor implementation, following the same educational approach used in *Digital Design and Computer Architecture* (Harris and Harris).

This processor executes one instruction per clock cycle (single-cycle datapath), integrating instruction fetch, decode, execute, memory access, and write-back in a single combinational pass between clock edges.

## Top-Level Architecture Definition
The top-level module is `cpu`, responsible for connecting all functional units and updating architectural state.

### Main Modules
| Module | Function |
|-----------------|-----------------|
| **cpu** | Integrates datapath and control path, updates PC, exports halt status |
| **instr_mem** | Read-only instruction memory, indexed by PC |
| **control_unit** | Decodes instruction and generates control signals |
| **register_file** | 32x32 general-purpose register bank with 2 read ports and 1 write port |
| **alu** | Arithmetic, logic, shift, and comparison operations |
| **data_mem** | Data memory for load/store operations |

### Datapath Overview
The datapath is composed of the following flow:
1. **Fetch**: `instr_mem` returns instruction indexed by current `pc`.
2. **Decode**: instruction fields are extracted (`opcode`, `rs`, `rt`, `rd`, `shamt`, `funct`, `imm`).
3. **Control**: `control_unit` generates all control signals from `opcode`, `funct`, and ALU flags.
4. **Execute**: ALU computes arithmetic/logical result, address, shift result, or comparison result.
5. **Memory**: `data_mem` is accessed for `LW/SW`.
6. **Write-back**: register file is updated with ALU result or loaded memory data.
7. **PC Update**: next PC is selected among sequential, branch target, or jump target.

## Architectural State
### Program Counter (PC)
- **Width**: `ADDR_W` bits (default: 8)
- **Behavior**:
  - Reset: `PC = 0`
  - Normal execution: `PC = pc_next`
  - Halt: PC is frozen while `halt = 1`
- **Addressing policy**: word-indexed PC (`pc + 1` advances to next instruction)

### Register File
- **Registers**: 32 registers (`NREGS = 32`)
- **Register width**: 32 bits
- **Ports**:
  - Read port 1: address `rs`
  - Read port 2: address `rt`
  - Write port: address selected by `regDst` (`rd` for R-type, `rt` for I-type)
- **Reset behavior**: all registers cleared to zero
- **Architectural role**: this is the processor's internal register file (CPU register bank), not a cache structure

### Registers Present in This Implementation
The current implementation contains the following architectural registers:
- **Program Counter (PC)**: 1 register, width `ADDR_W` (default 8 bits)
- **General-purpose register file**: 32 registers, 32 bits each (`R0` to `R31`)

No additional architectural special registers are implemented (for example: dedicated `SP`, `HI/LO`, `EPC`, status/coprocessor registers).

### Stack Support
This processor does not implement hardware stack support.

### Instruction Memory
- **Width**: 32-bit instructions
- **Depth**: 256 words
- **Access**: asynchronous read (`instr_out = mem[pc]`)
- **Initialization**: all words initialized to zero
- **Memory hierarchy role**: acts as the main program memory (instruction/text space, ROM-like behavior in this model)

### Data Memory
- **Width**: 32-bit words
- **Addressing**: word-indexed by `alu_out[ADDR_W-1:0]`
- **Write policy**: synchronous write on positive edge when `memWrite = 1`
- **Read policy**: combinational read via tri-state shared data bus
- **Initialization**: all words initialized to zero
- **Memory hierarchy role**: acts as the main data memory (read/write data space, RAM-like behavior in this model)

## Instruction Decode and Field Usage
The processor follows MIPS-like field extraction:

| Field | Bits | Meaning |
|-----------------|-----------------|-----------------|
| **opcode** | `[31:26]` | Main instruction class |
| **rs** | `[25:21]` | Source register 1 |
| **rt** | `[20:16]` | Source register 2 or destination (I-type) |
| **rd** | `[15:11]` | Destination register (R-type) |
| **shamt** | `[10:6]` | Shift amount for shift instructions |
| **funct** | `[5:0]` | R-type function selector |
| **imm** | `[15:0]` | Immediate value |

Immediate extension policy:
- **Zero-extension** for `ANDI`, `ORI`, `LUI`
- **Sign-extension** for all other immediate-based instructions

## Instruction Format Breakdown (R-Type, I-Type, J-Type)
This section defines the bit-level breakdown used by each instruction format in this project.

### R-Type (Register)

| opcode | rs | rt | rd | shamt | funct |
|-----------------|-----------------|-----------------|-----------------|-----------------|-----------------|
| 6 bits | 5 bits | 5 bits | 5 bits | 5 bits | 6 bits |

- **Usage in this design**: pure register operations and shifts.
- **Typical operations**: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`.
- **Field roles**:
  - `rs` and `rt`: source operands.
  - `rd`: destination register (`regDst = 1`).
  - `shamt`: shift amount for `SLL/SRL`.
  - `funct`: selects the exact ALU operation for opcode `000000`.

### I-Type (Immediate)

| opcode | rs | rt | immediate |
|-----------------|-----------------|-----------------|-----------------|
| 6 bits | 5 bits | 5 bits | 16 bits |

- **Usage in this design**: immediate arithmetic/logical ops, memory access, and conditional branches.
- **Typical operations**: `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`, `BEQ`, `BNE`, `BLT`.
- **Field roles**:
  - `rs`: base/source register.
  - `rt`: destination register for `LW`/immediate ops, or source register for `SW`/branches.
  - `immediate`: constant, offset, or branch displacement.

### J-Type (Jump)

| opcode | target |
|-----------------|-----------------|
| 6 bits | 26 bits |

- **Usage in this design**: unconditional jump (`JUMP`).
- **Field roles**:
  - `opcode`: identifies jump instruction.
  - `target`: jump target field.

### Project-Specific Note on Jump Addressing
In the current implementation, the jump next-PC is computed as:
- `pc_jump = instr[ADDR_W-1:0]`

So, although the instruction is conceptually J-type (26-bit target field), only the lower `ADDR_W` bits are used by the CPU because the PC is word-indexed and parameterized.

### Instruction vs Type vs Encoding Key Fields

| Instruction | Type | Key encoding fields used in this project |
|-----------------|-----------------|-----------------|
| **ADD** | R-Type | `opcode=000000`, `funct=100000`, `rs`, `rt`, `rd` |
| **SUB** | R-Type | `opcode=000000`, `funct=100010`, `rs`, `rt`, `rd` |
| **AND** | R-Type | `opcode=000000`, `funct=100100`, `rs`, `rt`, `rd` |
| **OR** | R-Type | `opcode=000000`, `funct=100101`, `rs`, `rt`, `rd` |
| **SLT** | R-Type | `opcode=000000`, `funct=101010`, `rs`, `rt`, `rd` |
| **SLL** | R-Type | `opcode=000000`, `funct=000000`, `rt`, `rd`, `shamt` |
| **SRL** | R-Type | `opcode=000000`, `funct=000010`, `rt`, `rd`, `shamt` |
| **ADDI** | I-Type | `opcode=001000`, `rs`, `rt`, `imm[15:0]` |
| **ANDI** | I-Type | `opcode=001100`, `rs`, `rt`, `imm[15:0]` (zero-extended) |
| **ORI** | I-Type | `opcode=001101`, `rs`, `rt`, `imm[15:0]` (zero-extended) |
| **LUI** | I-Type | `opcode=001111`, `rt`, `imm[15:0]` (zero-extended, shifted left 16 in ALU) |
| **LW** | I-Type | `opcode=100011`, `rs` (base), `rt` (dest), `imm[15:0]` |
| **SW** | I-Type | `opcode=101011`, `rs` (base), `rt` (src), `imm[15:0]` |
| **BEQ** | I-Type | `opcode=000100`, `rs`, `rt`, `imm[15:0]` |
| **BNE** | I-Type | `opcode=000101`, `rs`, `rt`, `imm[15:0]` |
| **BLT** | I-Type | `opcode=000110`, `rs`, `rt`, `imm[15:0]` |
| **JUMP** | J-Type | `opcode=000010`, `target[25:0]` (implementation uses low `ADDR_W` bits) |
| **HALT** | System (opcode-only) | `opcode=111111` |

## Control Unit Design
The control unit decodes instruction fields and emits control signals:

- `regWrite`
- `regDst`
- `aluSrc`
- `aluControl[2:0]`
- `memWrite`
- `memtoReg`
- `jump`
- `take_branch`
- `is_shift`
- `imm_is_zext`
- `halt`

### Internal Control Word
A 9-bit internal control word is used:

| Bit Group | Description |
|-----------------|-----------------|
| `regWrite` | Enable register write-back |
| `regDst` | Select destination register (`rd` vs `rt`) |
| `aluSrc` | Select ALU input B (`imm_ext` vs register value) |
| `aluControl[2:0]` | ALU operation code |
| `memWrite` | Enable memory write (`SW`) |
| `memtoReg` | Select write-back source (memory or ALU) |
| `jump` | Select jump PC target |

### Branch Policy
`take_branch` is generated by opcode and ALU flags:
- **BEQ**: branch when `aluOut_is_zero = 1`
- **BNE**: branch when `aluOut_is_zero = 0`
- **BLT**: branch when `signed_less = 1`

## ALU Design
The ALU is controlled by a 3-bit signal and supports:

| `aluControl` | Operation |
|-----------------|-----------------|
| `000` | AND |
| `001` | OR |
| `010` | ADD |
| `110` | SUB |
| `011` | SLL |
| `100` | SRL |
| `101` | LUI (`in_b << 16`) |
| `111` | SLT (signed comparison) |

Additional ALU outputs:
- **is_zero**: asserted when ALU result equals zero
- **signed_less**: signed less-than result with overflow-corrected subtraction logic

For shift instructions (`SLL`, `SRL`):
- ALU input A receives zero-extended `shamt`
- ALU input B receives register data (`rt`)

## Memory Interface Design
The data memory interface uses a shared tri-state data bus (`dm_data`):
- **Store (`SW`)**: CPU drives `dm_data` with `rf_data_out2`
- **Load (`LW`)**: CPU releases bus (`Z`), and memory drives `dm_data`

Write-back selection:
- If `memtoReg = 1`, register file receives memory data (`dm_data`)
- If `memtoReg = 0`, register file receives `alu_out`

## PC Update Logic
The next PC is selected with the following priority:
1. **Jump target** when `jump = 1`
2. **Branch target** when `take_branch = 1`
3. **Sequential** `pc + 1` otherwise

Definitions:
- `pc_plus1 = pc + 1`
- `pc_branch = pc_plus1 + imm_ext[ADDR_W-1:0]`
- `pc_jump = instr[ADDR_W-1:0]`

## Supported Instruction Classes in This Design
### R-Type
- `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`

### I-Type
- `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`

### Control Flow
- `BEQ`, `BNE`, `BLT`, `JUMP`

### System
- `HALT` (stops PC update and raises `halted` output)

## Implemented MIPS Subset
This project implements an educational subset of MIPS32 integer instructions, suitable for a single-cycle datapath inspired by Harris and Harris.

Implemented subset:
- **R-Type**: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`
- **I-Type (ALU/Immediate)**: `ADDI`, `ANDI`, `ORI`, `LUI`
- **I-Type (Memory)**: `LW`, `SW`
- **I-Type (Branch)**: `BEQ`, `BNE`, `BLT`
- **J-Type**: `JUMP`
- **System extension**: `HALT` (custom instruction for simulation/control)

Not part of this subset:
- Procedure/call instructions (e.g., `JAL`, `JR`)
- Multiply/divide instructions
- Exception/interrupt handling and privileged architecture state
- Coprocessor instructions
- Full MIPS32 ISA coverage

## Single-Cycle Execution Model
Each instruction is completed in one clock cycle:
- Combinational blocks (`instr_mem`, `control_unit`, ALU, muxes, memory read path) produce outputs within the cycle.
- Sequential state (`PC`, register file write, memory write) is updated at the rising edge.

This model simplifies control and verification, with the tradeoff that cycle time must accommodate the longest combinational path.

## Design Assumptions and Contracts
- Instruction and data memories are **word-addressed**.
- The memory model is a simplified Harvard-style split:
  - instruction memory is the main program memory
  - data memory is the main data memory
- The design has **no cache hierarchy** (no I-cache, no D-cache, no cache controller).
- `PC` is **instruction-indexed**, not byte-addressed.
- Branch offsets and jump targets use low `ADDR_W` bits.
- `HALT` disables PC update but preserves current architectural state.
- The architecture has **no hardware stack support** and no dedicated stack pointer register.
- Unknown/unsupported instructions produce neutral control outputs.

## Verification-Oriented Notes
The design is validated through dedicated testbenches for each module and integration tests for CPU behavior, including:
- Register operations
- R-type ALU operations
- Load/store behavior and address boundaries
- Branch and jump control flow
- Shift/immediate instructions
- Program-level tests (e.g., Fibonacci variants)

## References
- Harris, David Money; Harris, Sarah L. *Digital Design and Computer Architecture*.
- Patterson, David A.; Hennessy, John L. *Computer Organization and Design MIPS Edition*.
- Existing project implementation in Verilog (`cpu`, `control_unit`, `alu`, `register_file`, `instr_mem`, `data_mem`).
