# Pipelined MIPS-like CPU Architecture
## Introduction
The objective of this document is to describe the architecture and design decisions of our 32-bit MIPS-like 5-stage pipelined processor implementation, following the same educational approach used in *Digital Design and Computer Architecture* (Harris and Harris).

This processor overlaps the execution of multiple instructions across five pipeline stages — Fetch (F), Decode (D), Execute (E), Memory (M), and Writeback (W) — with one instruction per stage advancing every clock cycle under normal (hazard-free) operation. A dedicated hazard unit resolves data and control hazards via forwarding, stalling, and flushing instead of relying on compiler-inserted NOPs.

## Top-Level Architecture Definition
The top-level module is `pp_cpu`, responsible for connecting all functional units, sequencing the F/D/E/M/W pipeline registers, updating the PC, and exporting halt status.

### Main Modules
| Module | Function |
|-----------------|-----------------|
| **pp_cpu** | Integrates the 5-stage datapath, pipeline registers, and control path; updates PC; exports halt status |
| **hazard_unit** | Detects data/control hazards and drives forwarding muxes, stalls, and flushes |
| **instr_mem** | Read-only instruction memory, indexed by word (Fetch stage) |
| **control_unit** | Decodes instruction and generates control signals (Decode stage) |
| **register_file** | Shared general-purpose register bank; 32x32 bank with 2 read ports and 1 write port |
| **alu** | Arithmetic, logic, shift, and comparison operations (Execute stage) |
| **data_mem** | Data memory for load/store operations (Memory stage) |

### Datapath Overview
The datapath is organized into five pipeline stages, each separated by a clocked pipeline register (prefixed `D_`, `E_`, `M_`, `W_` for the instruction that has just crossed into that stage):

1. **Fetch (F)**: `instr_mem` returns the instruction indexed by the current `F_PC`; `F_PCplus4` and the next-PC selection (`F_PCnext`) are computed combinationally.
2. **Decode (D)**: instruction fields are extracted, `control_unit` decodes them, register operands are read, and — uniquely in this design — branch conditions are evaluated **in this stage** (see "Early Branch Resolution" below) rather than in Execute.
3. **Execute (E)**: ALU performs the arithmetic/logic/shift/address/comparison operation, with operands selected by the hazard unit's forwarding muxes.
4. **Memory (M)**: `data_mem` is accessed for `LW`/`SW` using the ALU result as address.
5. **Writeback (W)**: register file is updated with ALU result or loaded memory data.

## Architectural State
### Program Counter (PC)
- **Width**: `ADDR_W` bits (default: 32)
- **Behavior**:
  - Reset: `F_PC = 0`
  - Normal execution: `F_PC = F_PCnext` (only updates when `!D_halt && !F_stall`)
  - Halt: PC is frozen once `D_halt` is asserted
  - Stall: PC is frozen while `F_stall` is asserted (load-use or branch-operand hazard)
- **Addressing policy**: byte-addressed PC (`F_PC + 4` advances to the next instruction), matching `mc_cpu`

### Register File
- **Implementation location**: `source/design/cpu/common/register_file.v`
- **External parameterization**: `DATA_W` (default: 32)
- **Internal fixed organization**: 32 registers (`NREGS = 32`) with 5-bit register addresses
- **Register width in this CPU**: 32 bits
- **Ports**:
  - Read port 1: address `D_rs` (read in Decode)
  - Read port 2: address `D_rt` (read in Decode)
  - Write port: address `W_wa3`, written by the instruction currently in Writeback
- **Reset behavior**: all registers cleared to zero
- **Architectural role**: processor internal register bank (not a cache structure)

### Pipeline Registers
Because up to 5 instructions are in flight at once, `pp_cpu` keeps one register set per stage boundary instead of a single instruction register:

| Register set | Boundary | Notable fields |
|-----------------|-----------------|-----------------|
| **D** (Fetch→Decode) | `D_instr`, `D_PCplus4` | Cleared on reset/`D_CLR` (jump or taken branch); held on stall (`!D_EN`) |
| **E** (Decode→Execute) | `E_regWrite`, `E_memtoReg`, `E_memWrite`, `E_aluControl`, `E_aluSrc`, `E_regDst`, `E_imm_ext`, `E_rs/rt/rd/shamt`, `E_rf_out1/2` | Cleared on reset/`E_flush` (bubble injected by hazard unit) |
| **M** (Execute→Memory) | `M_regWrite`, `M_memtoReg`, `M_memWrite`, `M_wa3`, `M_writeData`, `M_aluOut` | Always advances (no stall/flush input) |
| **W** (Memory→Writeback) | `W_regWrite`, `W_memtoReg`, `W_wa3`, `W_dmOut`, `W_aluOut` | Always advances (no stall/flush input) |

`E_wa3 = E_regDst ? E_rd : E_rt` is computed once in Execute and carried through M and W as the pipelined write-address, so downstream stages (and the hazard unit) always know which register a given in-flight instruction will eventually write.

### Registers Present in This Implementation
- **Program Counter (PC)**: 1 register, width `ADDR_W` (default 32 bits)
- **General-purpose register file**: 32 registers, 32 bits each (`R0` to `R31`)
- **Pipeline registers**: D/E/M/W register sets described above (implementation detail of the pipeline, not user-visible architectural state)

No additional architectural special registers are implemented (for example: dedicated `SP`, `HI/LO`, `EPC`, status/coprocessor registers).

### Stack Support
This processor does not implement hardware stack support.

### Instruction Memory
- **Width**: 32-bit instructions
- **Depth**: `DEPTH` words (default: 256)
- **Access**: asynchronous read (`instr_out = ROM[addr_in]`)
- **Addressing at CPU interface**: `F_PC` is a byte address; `pp_cpu` converts it to a word index (`F_mem_addr_word = F_PC[ADDR_W-1:2]`) before indexing `instr_mem`
- **Initialization**: all words initialized to zero
- **Memory hierarchy role**: separate instruction memory (Harvard-style split with `data_mem`, unlike `mc_cpu`'s unified memory)

### Data Memory
- **Width**: 32-bit words
- **Addressing**: word-indexed by `M_mem_addr_word = M_aluOut[ADDR_W-1:2]` (ALU result from Execute, latched into `M_aluOut`, converted from byte to word index)
- **Write policy**: synchronous write on positive edge when `M_memWrite = 1`
- **Read policy**: combinational read via a dedicated output bus (`M_dmOut`)
- **Interface style**: single-ported memory with separate `data_in`/`data_out` buses, physically separate from `instr_mem`
- **Initialization**: all words initialized to zero

## Instruction Decode and Field Usage
The processor follows MIPS-like field extraction from `D_instr` in the Decode stage:

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

### R-Type (Register)

| opcode | rs | rt | rd | shamt | funct |
|-----------------|-----------------|-----------------|-----------------|-----------------|-----------------|
| 6 bits | 5 bits | 5 bits | 5 bits | 5 bits | 6 bits |

- **Usage in this design**: pure register operations and shifts.
- **Typical operations**: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`.
- **Field roles**:
  - `rs` and `rt`: source operands.
  - `rd`: destination register (`regDst = 1`).
  - `shamt`: shift amount for `SLL/SRL`, forwarded to Execute as `E_shamt` and used as ALU operand A.
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
  - `target`: jump target field (`D_addr`).

### Project-Specific Note on Jump Addressing
In this implementation, jump next-PC is computed in Fetch from the Decode-stage PC and target field:
- `F_PCjump = {D_PCplus4[ADDR_W-1:ADDR_W-4], D_addr, 2'b00}`

This matches MIPS-style pseudo-direct jump composition in a byte-addressed PC model, identical to `mc_cpu`'s jump formula.

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
The control unit (`control_unit`, shared with `sc_cpu`/`mc_cpu`) decodes `D_instr` and emits, purely combinationally in Decode:

- `regWrite`, `regDst`, `aluSrc`, `aluControl[2:0]`, `memWrite`, `memtoReg`, `jump`, `is_shift`, `imm_is_zext`, `halt`, `is_beq`, `is_bne`, `is_blt`

These signals are then carried down the pipeline in the D→E register (except `jump`/`halt`/branch flags, which are consumed entirely within Fetch/Decode since control flow is resolved there — see below).

## Early Branch Resolution (Decode Stage)
Unlike a textbook 5-stage design that resolves branches in Execute or later, this implementation resolves branch conditions **in Decode**, immediately after operands are read:

- `D_branch = D_is_beq | D_is_bne | D_is_blt`
- `D_take_branch_raw`:
  - **BEQ**: taken when `D_branchOperandA == D_branchOperandB`
  - **BNE**: taken when `D_branchOperandA != D_branchOperandB`
  - **BLT**: taken when `$signed(D_branchOperandA) < $signed(D_branchOperandB)` (signed comparison)
- `D_take_branch = D_take_branch_raw && !D_stall` — a branch decision is only accepted when Decode is not itself stalled that cycle (stale operands would otherwise redirect the PC incorrectly).
- `D_branchOperandA`/`D_branchOperandB` are the register-file outputs (`D_rf_out1`/`D_rf_out2`), optionally forwarded from the Memory stage via `D_forwardA`/`D_forwardB` (see Hazard Unit below), and additionally corrected for a same-cycle Writeback-stage RAW hazard via a direct WB→Decode bypass (`D_rf_out1_eff`/`D_rf_out2_eff`).

Resolving branches this early keeps the control-flow penalty to a single bubble (one Decode-stage flush, `D_CLR`), at the cost of needing Decode-stage forwarding (`forwardAD`/`forwardBD`) and a dedicated branch-operand stall to guarantee correctness — both implemented in `hazard_unit.v`.

## Hazard Unit Design (`hazard_unit.v`)
The hazard unit is purely combinational and receives register indices/write-enables from every stage; it drives the pipeline's forwarding muxes and stall/flush controls.

### Forwarding to Execute
| Signal | Priority | Source when asserted |
|-----------------|-----------------|-----------------|
| `forwardAE`/`forwardBE` = `2'b10` | Memory stage (highest) | `E_rs`/`E_rt` matches `M_wa3` and `M_regWrite` |
| `forwardAE`/`forwardBE` = `2'b01` | Writeback stage | `E_rs`/`E_rt` matches `W_wa3` and `W_regWrite` (checked only if Memory did not match) |
| `forwardAE`/`forwardBE` = `2'b00` | No hazard | Register-file value read in Decode (`E_rf_out1`/`E_rf_out2`) |

Memory-stage forwarding takes priority over Writeback because it holds the most recently produced value when both match the same destination register.

### Forwarding to Decode (early-branch operands)
| Signal | Condition | Source |
|-----------------|-----------------|-----------------|
| `forwardAD` | `D_rs == M_wa3 && M_regWrite` | `M_aluOut` |
| `forwardBD` | `D_rt == M_wa3 && M_regWrite` | `M_aluOut` |

Only the Memory stage is forwarded into Decode; a hazard against the Writeback stage or against Execute itself is instead resolved by stalling (see below), since a load result or an Execute-stage ALU result is not yet available in time for a same-cycle branch comparison.

### Load-Use Stall
```
lw_stall = E_memtoReg && ((E_rt == D_rs) || (E_rt == D_rt))
```
If the instruction in Execute is a load and its destination register is a source operand of the instruction currently in Decode, the pipeline cannot forward the value in time (it isn't available until the end of Memory). `F_stall`, `D_stall`, and `E_flush` all assert for one cycle: Fetch and Decode hold their state, and a bubble (all control signals zeroed) is injected into Execute.

### Branch Stall
```
branch_stall = (D_branch && E_regWrite && ((E_wa3 == D_rs) || (E_wa3 == D_rt)))
            || (D_branch && M_memtoReg && ((M_wa3 == D_rs) || (M_wa3 == D_rt)))
```
Because branches resolve in Decode (one stage earlier than a normal ALU forward would allow), a branch whose operand is still in Execute (not yet in Memory to be forwarded) or is a load result still in Memory (not yet in Writeback) must stall one cycle until the value becomes forwardable via `forwardAD`/`forwardBD` on a subsequent cycle.

### Control-Flow Flush
```
D_CLR = D_jump || D_take_branch
```
Squashes (invalidates) the instruction that was just fetched into Decode whenever a jump or a taken branch is resolved that same cycle, since that fetch followed the sequential path and is architecturally incorrect.

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

Operand selection in Execute:
- **ALU A (`E_aluA`)**: `E_shamt` (zero-extended) for shift instructions, otherwise the forwarded value `E_intermediateA` (register-file value or Memory/Writeback bypass)
- **ALU B (`E_aluB`)**: `E_imm_ext` when `E_aluSrc = 1`, otherwise the forwarded value `E_intermediateB`

## Memory Interface Design
The data memory interface is single-ported and uses separate input/output buses, accessed only from the Memory stage:
- **Store (`SW`)**: `M_writeData` (which is `E_intermediateB`, i.e. the post-forwarding `rt` value latched at the E→M boundary) is written to `data_mem` when `M_memWrite = 1`
- **Load (`LW`)**: `data_mem` returns the selected word on `M_dmOut`, latched into `W_dmOut` for Writeback

Write-back selection:
- If `W_memtoReg = 1`, register file receives `W_dmOut` (via `W_rf_in`)
- If `W_memtoReg = 0`, register file receives `W_aluOut`

## PC Update Logic
The next PC is selected in Fetch with the following priority, based on the Decode-stage instruction (since jump/branch are resolved in Decode, one stage ahead of Fetch):
1. **Jump target** (`F_PCjump`) when `D_jump = 1`
2. **Branch target** (`D_PCbranch`) when `D_take_branch = 1`
3. **Sequential** `F_PCplus4` otherwise

Definitions:
- `F_PCplus4 = F_PC + 4`
- `D_PCbranch = D_PCplus4 + (D_imm_ext << 2)` (branch immediate is a word offset, shifted left 2 for the byte-addressed PC domain)
- `F_PCjump = {D_PCplus4[ADDR_W-1:ADDR_W-4], D_addr, 2'b00}`

The PC register itself only updates when `!D_halt && !F_stall`.

## Supported Instruction Classes in This Design
### R-Type
- `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`

### I-Type
- `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`

### Control Flow
- `BEQ`, `BNE`, `BLT`, `JUMP`

### System
- `HALT` (decoded in Decode; freezes `F_PC` updates once `D_halt` propagates to the top-level `halt` output, while already-in-flight instructions in E/M/W continue draining)

## Implemented MIPS Subset
This project implements an educational subset of MIPS32 integer instructions, suitable for a 5-stage pipelined datapath inspired by Harris and Harris.

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

## Pipelined Execution Model
Under hazard-free operation, a new instruction enters Fetch every cycle and one instruction completes Writeback every cycle (steady-state throughput of 1 instruction/cycle), with a fixed 5-cycle latency from Fetch to Writeback for any single instruction. Hazards reduce throughput below this ideal:

- A **load-use hazard** costs 1 stall cycle (bubble in Execute).
- A **branch-operand hazard** costs 1 stall cycle before the branch can resolve.
- A **taken branch or jump** costs 1 flush cycle (bubble in Decode), since it is caught immediately in Decode rather than later in the pipeline.

This model trades the single-cycle design's long combinational path (and the multi-cycle design's variable per-instruction CPI) for pipeline registers and hazard-resolution logic, aiming for close-to-1 CPI at a shorter cycle time than `sc_cpu`.

## Design Assumptions and Contracts
- PC is **byte-addressed** and increments by `4` in Fetch, matching `mc_cpu`.
- Instruction and data memories are **separate** (Harvard-style split), each internally word-indexed; the CPU converts byte addresses to word indices at the `instr_mem`/`data_mem` boundary.
- The design has **no cache hierarchy** (no I-cache, no D-cache, no cache controller).
- Branches are resolved in **Decode**, one stage earlier than a conventional Execute-stage resolution, trading extra hazard-unit complexity (Decode-stage forwarding + branch stall) for a shorter (1-cycle) control-hazard penalty.
- `HALT` is decoded in Decode and freezes PC updates immediately, while instructions already past Decode are allowed to drain through Execute/Memory/Writeback and complete normally.
- The architecture has **no hardware stack support** and no dedicated stack pointer register.
- Unknown/unsupported instructions produce neutral control outputs (no write-enables asserted).

## Verification-Oriented Notes
The design is validated through dedicated testbenches, including:
- `hazard_unit_tb.sv`: isolated combinational verification of forwarding priority (Memory over Writeback) and stall/flush conditions (load-use, branch-operand)
- `pp_cpu_tb.sv`: full CPU-level regression reusing the shared instruction-set test suite (`source/verif/cpu/common/assembly/`) plus a canonical Harris & Harris MIPS test and a forwarding/stall/flush-heavy integration test
- Pipeline-specific trace modes (`+trace_m` for stage occupancy, `+trace_h` for hazard-unit decisions) to make hazard resolution directly observable during debugging

See [source/verif/cpu/pipelined/README.md](../../../../verif/cpu/pipelined/README.md) for the full test catalog and debugging workflow.

## References
- Harris, David Money; Harris, Sarah L. *Digital Design and Computer Architecture*.
- Patterson, David A.; Hennessy, John L. *Computer Organization and Design MIPS Edition*.
- Existing project implementation in Verilog (`pp_cpu`, `hazard_unit`, `control_unit`, `alu`, `register_file`, `instr_mem`, `data_mem`).
