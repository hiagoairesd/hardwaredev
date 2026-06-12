# Multi-Cycle MIPS-like CPU Architecture
## Introduction
The objective of this document is to describe the architecture and design decisions of our 32-bit MIPS-like multi-cycle processor implementation, following the same educational approach used in *Digital Design and Computer Architecture* (Harris and Harris).

This processor executes each instruction across multiple cycles, using an FSM-based control unit and reusing functional units (ALU and memory) across states over time.
In this context, memory reuse refers to temporal reuse of the same memory interface during different FSM states.
The memory module itself is local to the multi-cycle design (`source/design/cpu/multi_cycle/memory.v`).

## Top-Level Architecture Definition
The top-level module is `mc_cpu`, responsible for connecting datapath and control path, maintaining intermediate state registers, updating the PC, and exporting halt status.

### Main Modules
| Module | Function |
|-----------------|-----------------|
| **mc_cpu** | Integrates datapath and FSM control, updates PC, exports halt status |
| **mc_control_unit** | FSM-based control unit for multi-cycle sequencing |
| **memory** | Unified instruction/data memory (single-ported) |
| **register_file** | Shared general-purpose register bank (32x32, 2 read ports, 1 write port) |
| **alu** | Arithmetic, logic, shift, immediate, and comparison operations |

### Datapath Overview
The datapath is organized around multi-cycle execution with intermediate registers:
1. **Fetch**: unified memory is read using `PC`, instruction is latched in `instr` (`IRWrite = 1`).
2. **Decode/Register Fetch**: instruction fields are decoded and register operands are sampled into `rf_regA`/`rf_regB`.
3. **Execute/Address/Branch Prep**: ALU performs operation selected by FSM state (R-type ALU op, immediate ALU op, memory address calculation, or branch compare).
4. **Memory Access (if needed)**: memory is read (`LW`) or written (`SW`) using ALU-generated address.
5. **Write-back (if needed)**: register file is updated with memory data (`LW`) or ALU result (R-type/immediate).
6. **PC Update**: PC advances in fetch (`PC + 4`) and may be redirected for branch/jump.

## Architectural State
### Program Counter (PC)
- **Width**: `ADDR_W` bits (default in `mc_cpu`: 32)
- **Behavior**:
  - Reset: `PC = 0`
  - Fetch progression: `PC = PC + 4`
  - Branch/jump: `PC` updated according to `PCSrc` and `PCEn`
  - Halt: PC is frozen while `halt = 1`
- **Addressing policy**: byte-addressed PC

### Register File
- **Implementation location**: `source/design/cpu/common/register_file.v`
- **External parameterization**: `DATA_W` (default: 32)
- **Internal fixed organization**: 32 registers (`NREGS = 32`) with 5-bit register addresses
- **Register width in this CPU**: 32 bits
- **Ports**:
  - Read port 1: address `rs`
  - Read port 2: address `rt`
  - Write port: address selected by `regDst` (`rd` for R-type, `rt` for I-type/LW)
- **Reset behavior**: all registers cleared to zero
- **Architectural role**: processor internal register bank (not cache)

### Internal Multi-Cycle Registers
To support multi-cycle operation, `mc_cpu` includes the following internal state registers:
- `instr`: instruction register (IR)
- `rf_regA`: latched register operand A
- `rf_regB`: latched register operand B
- `alu_reg`: ALU output register (ALUOut-style latch)
- `mem_reg`: memory data register (MDR-style latch)

### Registers Present in This Implementation
The current implementation contains:
- **Program Counter (PC)**: 1 register, width `ADDR_W` (default 32 bits)
- **General-purpose register file**: 32 registers, 32 bits each (`R0` to `R31`)
- **Internal multi-cycle latches**: `instr`, `rf_regA`, `rf_regB`, `alu_reg`, `mem_reg`

No additional architectural special registers are implemented (for example: dedicated `SP`, `HI/LO`, `EPC`, status/coprocessor registers).

### Stack Support
This processor does not implement hardware stack support.

### Unified Memory
- **Width**: 32-bit words
- **Depth**: `MEM_DEPTH` words (default in `mc_cpu`: 256)
- **Access**: asynchronous read (`data_out = mem[addr]`)
- **Write policy**: synchronous write on positive edge when `we = 1`
- **Addressing at memory macro**: word-indexed (`addr` is a word index)
- **Addressing at CPU interface**:
  - CPU generates byte addresses (`pc`, ALU result)
  - CPU converts to word index using `mem_addr_word = {2'b00, mem_addr[ADDR_W-1:2]}`
- **Initialization**: all words initialized to zero
- **Memory hierarchy role**: unified main memory containing both instruction and data spaces

### Instruction/Data Region Contract
In `mc_cpu`, unified memory is partitioned logically:
- Instruction region: lower half (`0` to `INSTR_LIMIT-1`)
- Data region: upper half (`INSTR_LIMIT` to `MEM_DEPTH-1`)

Runtime contract in simulation (`ifndef SYNTHESIS`):
- Writes to instruction region are detected as violations and terminate simulation.

## Instruction Decode and Field Usage
The processor follows MIPS-like field extraction from `instr`:

| Field | Bits | Meaning |
|-----------------|-----------------|-----------------|
| **opcode** | `[31:26]` | Main instruction class |
| **rs** | `[25:21]` | Source register 1 |
| **rt** | `[20:16]` | Source register 2 or destination (I-type/LW) |
| **rd** | `[15:11]` | Destination register (R-type) |
| **shamt** | `[10:6]` | Shift amount for shift instructions |
| **funct** | `[5:0]` | R-type function selector |
| **imm** | `[15:0]` | Immediate value |
| **addr** | `[25:0]` | Jump target field |

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

- **Usage in this design**: immediate ALU ops, memory access, and conditional branches.
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
In this implementation, jump next-PC is computed as:
- `PCJump = {pc[ADDR_W-1:ADDR_W-4], addr, 2'b00}`

This matches MIPS-style pseudo-direct jump composition in a byte-addressed PC model.

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
| **JUMP** | J-Type | `opcode=000010`, `target[25:0]` |
| **HALT** | System (opcode-only) | `opcode=111111` |

## Control Unit Design
The control unit (`mc_control_unit`) is an FSM that decodes instruction/state context and emits:

- `PCEn`
- `is_shift`
- `imm_is_zext`
- `memToReg`
- `regDst`
- `IorD`
- `aluSrcA`
- `aluSrcB[1:0]`
- `PCSrc[1:0]`
- `IRWrite`
- `memWrite`
- `PCWrite`
- `regWrite`
- `aluControl[2:0]`
- `halt`

### Main FSM States
The implemented FSM states are:
- `FETCH`
- `DECODE`
- `MEM_ADR`
- `MEM_READ`
- `MEM_WRITEBACK`
- `MEM_WRITE`
- `EXECUTE`
- `ALU_WRITEBACK`
- `BRANCH`
- `IMM_WRITEBACK`
- `JUMP`
- `EXECUTE_IMM`
- `HALT`

### Typical State Flows by Instruction Class
- **R-Type**: `FETCH -> DECODE -> EXECUTE -> ALU_WRITEBACK`
- **LW**: `FETCH -> DECODE -> MEM_ADR -> MEM_READ -> MEM_WRITEBACK`
- **SW**: `FETCH -> DECODE -> MEM_ADR -> MEM_WRITE`
- **Immediate ALU** (`ADDI/ANDI/ORI/LUI`): `FETCH -> DECODE -> EXECUTE_IMM -> IMM_WRITEBACK`
- **Branches** (`BEQ/BNE/BLT`): `FETCH -> DECODE -> BRANCH`
- **JUMP**: `FETCH -> DECODE -> JUMP`
- **HALT**: `FETCH -> DECODE -> HALT` then remains in `HALT`

### Branch Policy
Branch decision is generated by opcode and ALU flags:
- **BEQ**: take when `aluOut_is_zero = 1`
- **BNE**: take when `aluOut_is_zero = 0`
- **BLT**: take when `signed_less = 1`

PC update enable is:
- `PCEn = PCWrite | (branch & take_branch)`

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
- **signed_less**: signed less-than result with overflow-aware subtraction logic

Operand selection in `mc_cpu`:
- **ALU A (`alu_a`)**:
  - `pc` during fetch/decode address calculations
  - `shamt` for shift instructions
  - `rf_regA` otherwise
- **ALU B (`alu_b`)**:
  - `rf_regB`
  - constant `4`
  - `imm_ext`
  - `imm_ext << 2` (branch target calculation)

## Memory Interface Design
The CPU uses unified single-ported memory with `IorD` selection:
- `IorD = 0`: instruction fetch address (`pc`)
- `IorD = 1`: data access address (`alu_reg`)

Data-path behavior:
- **Store (`SW`)**: `rf_regB` is written to memory when `memWrite = 1`
- **Load (`LW`)**: memory output is latched in `mem_reg`, then written back when `memToReg = 1`

Write-back selection:
- If `memToReg = 1`, register file receives `mem_reg`
- If `memToReg = 0`, register file receives `alu_reg`

## PC Update Logic
PC next value is selected by `PCSrc` in `mc_cpu`:
1. `PCSrc = 2'b00`: ALU output (sequential fetch path, `PC + 4`)
2. `PCSrc = 2'b01`: branch target from `alu_reg`
3. `PCSrc = 2'b10`: jump target (`PCJump`)

Definitions:
- `PCJump = {pc[ADDR_W-1:ADDR_W-4], addr, 2'b00}`
- Branch target precomputed in decode using `pc + (imm_ext << 2)` and latched in `alu_reg`

## Supported Instruction Classes in This Design
### R-Type
- `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`

### I-Type
- `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`

### Control Flow
- `BEQ`, `BNE`, `BLT`, `JUMP`

### System
- `HALT` (halts control FSM and freezes architectural progression)

## Implemented MIPS Subset
This project implements an educational subset of MIPS32 integer instructions, suitable for an FSM-based multi-cycle datapath inspired by Harris and Harris.

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

## Multi-Cycle Execution Model
Each instruction is executed over multiple cycles according to FSM state flow:
- Fetch/decode stages are shared.
- ALU, memory, and write-back are scheduled in later states depending on instruction class.
- Intermediate values are stored in dedicated internal registers (`instr`, `rf_regA/B`, `alu_reg`, `mem_reg`).

This model reduces combinational critical path versus single-cycle design, with the tradeoff of variable CPI by instruction type.

## Design Assumptions and Contracts
- PC is **byte-addressed** and increments by `4` in fetch.
- Memory is **unified and word-indexed internally**; CPU byte addresses are converted to word index (`addr[31:2]`).
- The model is simplified (no cache hierarchy, no MMU).
- Instruction/data separation is a logical contract over a shared memory array.
- In simulation, writes to instruction region are treated as fatal violations.
- Branch displacement uses `imm_ext << 2`.
- `HALT` causes control to remain in `HALT` state with side-effect enables disabled.
- Unknown/unsupported instructions in decode fall back to fetch with neutral controls.

## Verification-Oriented Notes
The design is validated through dedicated testbenches and integration tests, including:
- R-type ALU operations
- Immediate operations (`ADDI/ANDI/ORI/LUI`)
- Load/store behavior and address conversion
- Branch and jump control flow
- Shift operation behavior (`SLL/SRL`)
- Program-level scenarios (loops, Fibonacci, integration)

## References
- Harris, David Money; Harris, Sarah L. *Digital Design and Computer Architecture*.
- Patterson, David A.; Hennessy, John L. *Computer Organization and Design MIPS Edition*.
- Existing project implementation in Verilog (`mc_cpu`, `mc_control_unit`, `memory`, `alu`, `register_file`).
