# Pipelined CPU Testbench Documentation

## Overview

The pipelined CPU testbench (`pp_cpu_tb.sv`) provides a comprehensive test suite for validating the 5-stage pipelined MIPS-like processor design (Fetch → Decode → Execute → Memory → Writeback). The testbench implements 21 distinct test cases, reusing the shared instruction-set regression suite from `source/verif/cpu/common/assembly/` plus two pipeline-specific programs (the Harris & Harris canonical `mipstest` and a wide `integration` program that exercises forwarding, stalling, and branch flushing together).

Because up to 5 instructions are in flight simultaneously (one per pipeline stage), this testbench differs from `sc_cpu_tb.sv`/`mc_cpu_tb.sv` in two important ways:
- It waits a few extra cycles (`drain_cycles`) after HALT is decoded so in-flight instructions can retire before checking architectural state.
- It exposes two extra trace modes (`+trace_m`, `+trace_h`) to visualize pipeline occupancy and hazard-unit decisions, since there is no single "current state" to print like in `mc_cpu`.

A companion unit-level testbench, `hazard_unit_tb.sv`, verifies the hazard/forwarding unit (`hazard_unit.v`) in isolation.

**Key Resources:**
- **RTL Design:** `source/design/cpu/pipelined/` (`pp_cpu.v`, `hazard_unit.v`) and reused common modules in `source/design/cpu/common/`
- **Testbenches:** `source/verif/cpu/pipelined/pp_cpu_tb.sv`, `source/verif/cpu/pipelined/hazard_unit_tb.sv`
- **Assembly Programs:** `source/verif/cpu/common/assembly/` (shared with SC/MC) and `source/verif/cpu/pipelined/assembly/` (pipeline-specific)
- **Simulation Script:** `simu/simulate`

## Running Tests

### Prerequisites

1. **Icarus Verilog** (or compatible Verilog simulator)
2. **SystemVerilog support** enabled in simulator

### Basic Test Execution

```bash
cd simu/
./simulate pp_cpu +test=<test_id> [+trace] [+trace_w] [+trace_m] [+trace_h]
```

### Hazard Unit (standalone)

```bash
cd simu/
./simulate hazard_unit
```

### Test Selection Options

| Test ID | Program File | Purpose |
|---------|-------------|---------|
| 1 | `regs.hex` | Basic register writes |
| 2 | `basic_swlw.hex` | SW/LW basic path and addressing |
| 3 | `border_swlw.hex` | Immediate sign extension and memory boundary |
| 4 | `rtype.hex` | Core ALU R-type operations |
| 5 | `jump.hex` | Unconditional jump (J-type) |
| 6 | `beq.hex` | BEQ taken/not-taken and loop |
| 7 | `andi.hex` | ANDI zero-extension and bit masking |
| 8 | `ori.hex` | ORI zero-extension and bit assembly |
| 9 | `lui.hex` | LUI upper-16-bit placement |
| 10 | `sll.hex` | SLL shifting and edge conditions |
| 11 | `srl.hex` | SRL logical right shift |
| 12 | `bne.hex` | BNE taken/not-taken |
| 13 | `blt.hex` | BLT taken |
| 14 | `fibonacci.hex` | Fibonacci sequence (fib(20) = 4181) |
| 15 | `fibonacci_overflow.hex` | Fibonacci with 32-bit overflow |
| 16 | `zero_register_protection.hex` | Register-write smoke test |
| 17 | `halt_placement.hex` | HALT stops execution of subsequent instructions |
| 18 | `loop_counter.hex` | BLT-driven loop with accumulation |
| 19 | `array_sum.hex` | Multiple SW/LW accesses with final reduction |
| 20 | `mipstest.hex` | Canonical Harris & Harris MIPS sanity program |
| 21 | `integration.hex` | Full integration (all instruction classes, forwarding/stalls/branches) |
| **default** | `integration.hex` | Same as test 21 |

Tests 1–19 load their program from `source/verif/cpu/common/assembly/` (shared with `sc_cpu_tb.sv`/`mc_cpu_tb.sv`); test 20 loads from `source/verif/cpu/pipelined/assembly/mipstest.hex`; test 21/default loads `source/verif/cpu/common/assembly/integration.hex`.

### Trace Options

```bash
./simulate pp_cpu +test=1                      # Run test 1, no trace
./simulate pp_cpu +test=1 +trace_w             # Commit trace (reg/mem writes, branches, jumps)
./simulate pp_cpu +test=1 +trace               # Lightweight trace (PC, instr) + forces trace_w
./simulate pp_cpu +test=1 +trace_m             # Pipe diagram (PC occupying F/D/E/M/W each cycle)
./simulate pp_cpu +test=1 +trace_h             # Hazard trace (STALL/FLUSH/FORWARD events)
```

## Test Suite Details

### Test 1: Basic Register Writes (`regs.hex`)

- **Purpose:** Validates basic register write paths through the pipeline.
- **PASS criteria:**

| Register | Expected Value |
|----------|---------------|
| R1 | 1 |
| R2 | 2 |
| R3 | 3 |

---

### Test 2: Basic SW/LW (`basic_swlw.hex`)

- **Purpose:** Validates the SW/LW basic path and addressing, including MEM→ALU forwarding for the immediately following LW.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 42 |
| MEM[128] | 42 |
| R2 | 42 (loaded back from MEM[128]) |

---

### Test 3: Border SW/LW (`border_swlw.hex`)

- **Purpose:** Edge cases for immediate sign extension and memory boundary accesses.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 32767 (0x7FFF) |
| R2 | −32768 (0x8000) |
| R3 | −1 (0xFFFFFFFF) |
| MEM[(0xFF>>2)+128] | −1 |
| R4 | −1 |
| R5 | 0 |

---

### Test 4: R-Type ALU (`rtype.hex`)

- **Purpose:** Validates core ALU operations (ADD, SUB, AND, OR, SLT) with back-to-back register dependencies (forwarding-heavy).
- **PASS criteria:**

| Register | Expected |
|----------|---------|
| R1 | 5 |
| R2 | 3 |
| R3 | 8 (R1 + R2) |
| R4 | 2 (R1 − R2) |
| R5 | 1 (R1 AND R2) |
| R6 | 7 (R1 OR R2) |
| R7 | 1 (SLT: R2 < R1) |
| R8 | 0 (SLT: R1 < R2 → false) |

---

### Test 5: Jump (`jump.hex`)

- **Purpose:** Validates J-type unconditional jump behavior, including the one-cycle Decode-stage flush (`D_CLR`) of the instruction fetched behind the jump.
- **PASS criteria:**

| Register | Expected | Notes |
|----------|---------|-------|
| R1 | 1 | Executed before jump |
| R2 | 0 | Squashed by jump (bubble in Decode) |
| R3 | 0 | Squashed by jump |
| R4 | 4 | Executed at jump target |

---

### Test 6: BEQ (`beq.hex`)

- **Purpose:** Validates BEQ taken/not-taken paths and loop correctness, resolved early in Decode.
- **PASS criteria:**

| Register | Expected |
|----------|---------|
| R1 | 5 |
| R2 | 5 |
| R3 | 0 |
| R4 | 7 |
| R5 | 9 |
| R6 | 123 |

---

### Test 7: ANDI (`andi.hex`)

- **Purpose:** Validates ANDI zero-extension policy and bit masking.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 305397760 (0x123400FF & 0xFF00 = 0x1234_0000) |
| R2 | 305398015 (0x12340000 \| 0xFF = 0x123400FF) |
| R3 | 15 (0xFF & 0x0F) |
| R4 | 240 (0xFF & 0xF0) |
| MEM[128] | 15 |
| MEM[132] | 240 |

---

### Test 8: ORI (`ori.hex`)

- **Purpose:** Validates ORI zero-extension and bit assembly.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 0 |
| R2 | 1 |
| R3 | 241 (0xF0 \| 0x01) |
| R4 | 3855 (0x0F0F) |
| R5 | 4095 (0x0FFF) |
| MEM[128] | 241 |
| MEM[132] | 4095 |

---

### Test 9: LUI (`lui.hex`)

- **Purpose:** Validates LUI placement of upper 16 bits and subsequent operations.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 305397760 (0x12340000) |
| R2 | 0 |
| R3 | 4294901760 (0xFFFF0000) |
| R4 | 305441741 (LUI + ORI) |
| MEM[128] | 305397760 |
| MEM[132] | 4294901760 |
| MEM[136] | 305441741 |

---

### Test 10: SLL (`sll.hex`)

- **Purpose:** Validates SLL shifting and edge conditions (ALU operand A takes `shamt` for shift instructions).
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 1 |
| R2 | 16 (1 << 4) |
| R3 | 32 (1 << 5) |
| R4 | 240 (0x0F << 4) |
| R5 | 61440 (0x0F << 12) |
| MEM[128] | 16 |
| MEM[132] | 61440 |

---

### Test 11: SRL (`srl.hex`)

- **Purpose:** Validates SRL logical right shift and zero-fill behavior.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 2147483648 (0x80000000) |
| R2 | 1073741824 (0x40000000, >> 1) |
| R3 | 240 (0xF0) |
| R4 | 15 (0xF0 >> 4) |
| R5 | 0 (shifted out) |
| MEM[128] | 1073741824 |
| MEM[132] | 15 |

---

### Test 12: BNE (`bne.hex`)

- **Purpose:** Validates BNE taken/not-taken paths.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 1 |
| R2 | 2 |
| R3 | 0 |
| R4 | 5 |
| R5 | 5 |
| R6 | 13107 (0x3333) |
| MEM[128] | 13107 |

---

### Test 13: BLT (`blt.hex`)

- **Purpose:** Validates BLT (branch if less than) taken path.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| MEM[128] | 1 |
| MEM[129] | 1 |
| MEM[130] | 1 |

---

### Test 14: Fibonacci (`fibonacci.hex`)

- **Purpose:** Validates a longer loop-based program driving the hazard unit continuously (accumulate → store → load-back each iteration). Computes Fibonacci up to fib(20) = 4181.
- **PASS criteria (selected):**

| Signal | Expected |
|--------|---------|
| R1 | 0x0A18 (2584) |
| R2 | 0x1055 (4181) |
| R4 | 0x0014 (20 iterations) |
| R7 | 1 |
| MEM[128..147] | Fibonacci sequence: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181 |
| MEM[158] | 1 (success flag) |
| MEM[159] | 0x1055 = 4181 (final value fib(20)) |

---

### Test 15: Fibonacci Overflow (`fibonacci_overflow.hex`)

- **Purpose:** Validates behavior when the Fibonacci sequence exceeds the 32-bit boundary. Computes Fibonacci values until wrap-around occurs.
- **Key results:**

| Signal | Expected | Notes |
|--------|---------|-------|
| R1 | 0x43A53F82 | fib(45) |
| R2 | 0x6D73E55F | fib(46) |
| R3 | 0xB11924E1 | fib(47) wrapped (overflow) |
| R4 | 0x2F (47 dec) | iteration count |
| MEM[158] | 1 | success flag |
| MEM[159] | 0x6D73E55F | last valid value fib(46) |
| MEM[160] | 0xB11924E1 | first overflow value fib(47) |

---

### Test 16: Zero Register Protection (`zero_register_protection.hex`)

- **Purpose:** Register-write smoke test.
- **PASS criteria:**

| Register | Expected |
|----------|---------|
| R1 | 5 |
| R2 | 5 |

---

### Test 17: HALT Placement (`halt_placement.hex`)

- **Purpose:** Validates that instructions fetched after HALT never commit.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 1 |
| MEM[128] | 0 |

---

### Test 18: Loop Counter (`loop_counter.hex`)

- **Purpose:** Validates a BLT-driven loop with accumulation, including repeated branch-hazard stalls across iterations.
- **PASS criteria:**

| Register | Expected |
|----------|---------|
| R1 | 11 |
| R2 | 11 |
| R3 | 55 |
| MEM[128] | 55 |

---

### Test 19: Array Sum (`array_sum.hex`)

- **Purpose:** Validates multiple SW/LW accesses over an array and a final reduction, exercising load-use stalls back to back.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| MEM[144] | 10 |
| MEM[145] | 20 |
| MEM[146] | 30 |
| R2 | 10 |
| R3 | 20 |
| R4 | 30 |
| R5 | 60 |
| MEM[128] | 60 |

---

### Test 20: MIPS Test (`mipstest.hex`)

- **Purpose:** Canonical MIPS sanity program (Harris & Harris, *Digital Design and Computer Architecture*), exercising `add/sub/and/or/slt/addi/lw/sw/beq/j` in sequence. If the design is correct, the program writes the value 7 to data memory address 84 (byte) as its final act.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R2 | −4 |
| R3 | 12 |
| R4 | 1 |
| R5 | 0 |
| R7 | −4 |
| MEM[20] | −4 |
| MEM[21] | 0 |

---

### Test 21 / Default: Integration Test (`integration.hex`)

- **Purpose:** Validates all supported instruction classes working together end-to-end: R-type ALU, immediates, loads/stores, all three branch types, jump, and HALT — deliberately arranged to trigger forwarding from both Memory and Writeback stages, load-use stalls, and branch flushes in the same run.
- **PASS criteria (selected):**

| Signal | Expected |
|--------|---------|
| R1 | 15 |
| R2 | 6 |
| R5 | 0x123400f0 |
| R15 | 532 |
| R27 | 0xffffffff |
| R28 | 0xffffffff |
| MEM[128..132] | 1, 3, 6, 10, 15 |
| MEM[133] | 0xffffffff |
| MEM[134] | 0 |

See `integration_test()` in `pp_cpu_tb.sv` for the full register/memory assertion list.

---

## Hazard Unit Testbench (`hazard_unit_tb.sv`)

Unlike the CPU-level tests above, `hazard_unit_tb.sv` drives `hazard_unit.v` directly (no clock, no memory, no program load) with combinational stimulus and `#1` settling delays. It has no `+test=<id>` selector — a single `initial` block runs every case in sequence and calls `$finish` at the end.

| Section | Cases | What it checks |
|---------|-------|-----------------|
| Forwarding | `test_no_hazard`, `test_forwardAE_from_M`, `test_forwardAE_from_W`, `test_forwardBE_priority_M_over_W`, `test_forward_decode_from_M` | `forwardAE`/`forwardBE` select Memory (`2'b10`) over Writeback (`2'b01`) when both match; `forwardAD`/`forwardBD` bypass the early-branch comparator from Memory only |
| Stall/Flush | `test_lw_stall_on_D_rs`, `test_lw_stall_on_D_rt`, `test_branch_stall_from_E`, `test_branch_stall_from_M_load` | Load-use hazard (`E_memtoReg` + matching `D_rs`/`D_rt`) and branch-operand hazard (`D_branch` + matching `E_wa3`/`M_wa3`) both assert `F_stall`/`D_stall`/`E_flush` together |

Each case calls `expect_all(...)` which checks all 7 hazard-unit outputs at once and `$finish`s immediately on the first mismatch (`[FAIL] ... got=... expected=...`). On success the run ends with `ALL TESTS PASSED (<n> cases)`. A `#200` watchdog guards against a hang.

```bash
cd simu/
./simulate hazard_unit
```

---

## Testbench Architecture

### Test Loader and Dispatcher

The testbench uses `task automatic pick_test(input integer test_id)` with a `case(test_id)` to load the selected program into instruction memory:

```systemverilog
task automatic pick_test(input integer test_id);
  begin
    case(test_id)
      1:  $readmemh("../source/verif/cpu/common/assembly/regs.hex",               DUT.instr_mem.ROM);
      2:  $readmemh("../source/verif/cpu/common/assembly/basic_swlw.hex",         DUT.instr_mem.ROM);
      ...
      20: $readmemh("../source/verif/cpu/pipelined/assembly/mipstest.hex",        DUT.instr_mem.ROM);
      21: $readmemh("../source/verif/cpu/common/assembly/integration.hex",        DUT.instr_mem.ROM);
      default:
          $readmemh("../source/verif/cpu/common/assembly/integration.hex",        DUT.instr_mem.ROM);
    endcase
  end
endtask
```

Note the memory handle is `DUT.instr_mem.ROM` (not `.mem`, as in `sc_cpu_tb`/`mc_cpu_tb`) — `pp_cpu`'s `instr_mem` instance names its storage array `ROM`.

### Test Execution Flow

1. **Test selection** (from `+test=<id>` plusarg)
2. **Reset asserted** (`rst = 1`) for 2 clock cycles, program loaded via `pick_test(id)` while reset is held
3. **Reset deasserted** (`rst = 0`)
4. **Run until HALT or timeout** (`max_cycles = 2500`) — `DUT.halt` is polled every cycle; HALT is decoded in the Decode stage (`D_halt`), so it fires while older instructions may still be draining through Execute/Memory/Writeback
5. **Drain** (`drain_cycles = 4`) — additional cycles are run after HALT is first seen so all in-flight instructions retire before checks run
6. **Verification dispatch** via `case(id)` (e.g., `fibonacci_test()`, `integration_test()`)

### Trace Output Format

#### Lightweight Trace (`+trace`)
```
t = 10 [PC = 0] [Instr = 20020005]
t = 12 [PC = 4] [Instr = 20030003]
...
-> HALT detected @500 (PC=0x0000002A)
```

#### Commit Trace (`+trace_w`)
Each event is printed from the stage that actually owns it (W for regwrite, M for memwrite, D for branch/jump):
```
t=10    >>> REGWRITE | R1 <= 00000001 (Committed)
t=20    >>> MEMWRITE | mem[128] <= 0000002A
t=30    >>> BRANCH EVAL | rs=R2(00000005) rt=R3(00000005) take=1
t=30    >>> BRANCH Taken -> Target: 12
t=40    >>> JUMP -> Target: 48
```

#### Pipe Diagram (`+trace_m`)
Shows which PC (or `bubble` if squashed) occupies each of F/D/E/M/W this cycle — useful for seeing exactly where a stall or flush injected a bubble:
```
t=10 [PIPE] F:8 D:4 E:bubble M:0 W:bubble
t=12 [PIPE] F:12 D:8 E:4 M:bubble W:0
...
```

#### Hazard Trace (`+trace_h`)
One line per cycle, folding every active hazard-unit decision that cycle into a single `[HZ]` line (only active tags are printed):
```
t=30    [HZ] STALL(lw):R2,R3<-E.rt=R2 
t=40    [HZ] FLUSH(B->12) 
t=50    [HZ] FWD_EX[A:M(R1) B:W(R3)] 
t=60    [HZ] FWD_DE[A:M(R5)] 
```

## Assembly Program Format

Programs are stored as 32-bit hex values, one instruction per line, and loaded into instruction memory by word index (PC is byte-addressed at the CPU boundary, but `instr_mem` is accessed by word index — the CPU converts `F_PC` to `F_mem_addr_word = F_PC[ADDR_W-1:2]`):

```
20020001      # ADDI R2, R0, 1
20030002      # ADDI R3, R0, 2
fc000000      # HALT
```

**Instruction encoding (MIPS-like):**
- I-type: `[opcode:6][rs:5][rt:5][imm:16]`
- R-type: `[opcode:6][rs:5][rt:5][rd:5][shamt:5][funct:6]`
- J-type: `[opcode:6][addr:26]`

## Pipeline Hazard Handling

`pp_cpu` resolves data and control hazards without a scoreboard or explicit NOP injection, using `hazard_unit.v`:

- **Forwarding to Execute** (`forwardAE`/`forwardBE`, 2-bit): bypasses the ALU operands from Memory (`2'b10`, `M_aluOut`) or Writeback (`2'b01`, `W_rf_in`) when the Decode-stage-sourced operand in Execute is stale. Memory takes priority over Writeback when both match (most-recent producer wins).
- **Forwarding to Decode** (`forwardAD`/`forwardBD`, 1-bit): bypasses the early-branch comparator operands from Memory only, avoiding a stall on `beq`/`bne`/`blt` immediately following an ALU producer.
- **Load-use stall**: if the instruction in Execute is a load (`E_memtoReg`) and its destination (`E_rt`) matches either source register of the instruction in Decode, `F_stall`/`D_stall`/`E_flush` all assert for one cycle — Fetch and Decode hold their registers and a bubble is punched into Execute.
- **Branch stall**: if the instruction in Decode is a branch and its source registers match the destination of the instruction currently in Execute (not yet ready) or a load currently in Memory (`M_memtoReg`), the same `F_stall`/`D_stall`/`E_flush` triple fires so the branch waits for its operands before resolving.
- **Control-flow flush**: `D_CLR = D_jump || D_take_branch` squashes the instruction just fetched into Decode (one-cycle bubble) whenever a jump or a taken branch is resolved in Decode.

Use `+trace_h` with `pp_cpu_tb` to observe these events directly, or drive `hazard_unit.v` in isolation with `hazard_unit_tb.sv`.

## Expected Test Results

**Default run (`./simulate pp_cpu`)**

```
----------------------- RUNNING INTEGRATION TESTS [20/default] ---------------
...
----------------------- TESTS PASSED -------------------------
```

**Manual full regression (tests 1–21):**

```
✓ Test  1 (regs)                PASS
...
✓ Test 21 (integration)         PASS

Total: 21/21 PASS
```

## Debugging Tips

### Timeout (Program Never Halts)

**Symptoms:** Simulation runs past `max_cycles` (2500) without `DUT.halt` ever asserting

**Likely causes:**
1. **Missing HALT instruction** in program hex file
2. **Infinite loop:** Branch condition always true, backward offset causes loop
3. **PC corruption:** `F_PCnext` selection logic (jump/branch/sequential) sends PC to undefined location

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_m 2>&1 | tail -50
# Look for repeating PC values in the [PIPE] F: column
```

### Write-Back to Wrong Register

**Symptoms:** Expected value in R1, but R2 was written instead

**Likely causes:**
1. **`regDst` signal wrong:** selects `rt` instead of `rd` for R-type (`E_wa3 = E_regDst ? E_rd : E_rt`)
2. **`memtoReg` wrong:** Writeback selects ALU result when it should select memory data (or vice versa)

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_w | grep REGWRITE
# Verify correct register index and data value
```

### Wrong Value Only When a Dependent Instruction Immediately Follows a Producer

**Symptoms:** Correct result standalone, wrong result only in back-to-back instruction sequences

**Likely causes:**
1. **Missing/incorrect forwarding path:** `forwardAE`/`forwardBE` not selecting the right source, or Memory-over-Writeback priority inverted
2. **Missing Decode-stage forwarding:** an early branch immediately after an ALU producer reads a stale operand instead of using `forwardAD`/`forwardBD`

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_h | grep FWD
# Confirm FWD_EX/FWD_DE fire at the expected cycle with the expected source (M vs W)
```

### Wrong Value or a Stall That Never Resolves After a Load

**Symptoms:** Value used right after a `lw` is stale, or the pipeline hangs

**Likely causes:**
1. **`lw_stall` condition wrong** in `hazard_unit.v` (`E_memtoReg && (E_rt==D_rs || E_rt==D_rt)`)
2. **Stall not actually holding Fetch/Decode:** check `F_stall`/`D_EN` gating on `F_PC`/`D_instr` registers in `pp_cpu.v`

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_h | grep 'STALL(lw)'
# If it never fires where expected, re-check hazard_unit's lw_stall condition;
# cross-check with hazard_unit_tb.sv's test_lw_stall_on_D_rs/D_rt cases
```

### Wrong Memory Address

**Symptoms:** Data written to `mem[132]` instead of `mem[128]`

**Likely causes:**
1. **Byte-to-word conversion bug:** `M_mem_addr_word = M_aluOut[ADDR_W-1:2]` mismatched with `F_mem_addr_word`
2. **Immediate not sign-extended:** negative offset treated as large positive

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_w | grep MEMWRITE
# Verify address (mem word index) matches expected value
```

### Branch Not Taken When Expected

**Symptoms:** BEQ skips target, or BLT fires on equal values

**Likely causes:**
1. **Comparator policy:** signed vs. unsigned comparison for BLT
2. **Condition inverted:** BNE triggers on equality instead of inequality
3. **Stale operands:** branch resolved in Decode against pre-forwarding data (`D_forwardA`/`D_forwardB` not applied)

**Debug steps:**
```bash
./simulate pp_cpu +test=<failed_id> +trace_w | grep BRANCH
# Verify branch direction matches expected taken/not-taken
```

## File Organization

```
hardwaredev/
├── source/
│   ├── design/
│   │   ├── cpu/
│   │   │   ├── pipelined/
│   │   │   │   ├── pp_cpu.v          # Top-level 5-stage pipelined CPU
│   │   │   │   ├── hazard_unit.v     # Forwarding/stall/flush logic
│   │   │   │   ├── ISA/
│   │   │   │   │   └── ARCHITECTURE.md
│   ├── verif/
│   │   ├── cpu/
│   │   │   ├── pipelined/
│   │   │   │   ├── pp_cpu_tb.sv           # Main CPU testbench
│   │   │   │   ├── hazard_unit_tb.sv      # Hazard unit unit-testbench
│   │   │   │   ├── README.md              # This documentation
│   │   │   │   ├── assembly/
│   │   │   │   │   └── mipstest.hex       # Test 20: canonical MIPS sanity program
│   │   │   ├── common/
│   │   │   │   ├── assembly/              # Shared programs (tests 1-19, 21/default)
│   │   │   │   │   ├── regs.hex           # Test 1: basic register writes
│   │   │   │   │   ├── basic_swlw.hex     # Test 2: SW/LW basic path
│   │   │   │   │   ├── border_swlw.hex    # Test 3: immediate boundary
│   │   │   │   │   ├── rtype.hex          # Test 4: ALU R-type
│   │   │   │   │   ├── jump.hex           # Test 5: J-type jump
│   │   │   │   │   ├── beq.hex            # Test 6: BEQ
│   │   │   │   │   ├── andi.hex           # Test 7: ANDI
│   │   │   │   │   ├── ori.hex            # Test 8: ORI
│   │   │   │   │   ├── lui.hex            # Test 9: LUI
│   │   │   │   │   ├── sll.hex            # Test 10: SLL
│   │   │   │   │   ├── srl.hex            # Test 11: SRL
│   │   │   │   │   ├── bne.hex            # Test 12: BNE
│   │   │   │   │   ├── blt.hex            # Test 13: BLT
│   │   │   │   │   ├── fibonacci.hex      # Test 14: Fibonacci fib(20)
│   │   │   │   │   ├── fibonacci_overflow.hex # Test 15: Fibonacci with overflow
│   │   │   │   │   ├── zero_register_protection.hex # Test 16
│   │   │   │   │   ├── halt_placement.hex # Test 17
│   │   │   │   │   ├── loop_counter.hex   # Test 18
│   │   │   │   │   ├── array_sum.hex      # Test 19
│   │   │   │   │   └── integration.hex    # Test 21 / default
├── simu/
│   ├── simulate                           # Unified simulation script
```

## Integration Tips for CI/CD

### Run specific test
```bash
cd simu
./simulate pp_cpu +test=6
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run default mode (integration only)
```bash
cd simu
./simulate pp_cpu
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run full regression
```bash
cd simu
for i in {1..21}; do
  echo "Running test $i"
  ./simulate pp_cpu +test=$i || exit 1
done
./simulate hazard_unit || exit 1
```

### Parse results for CI
```bash
cd simu
for i in {1..21}; do ./simulate pp_cpu +test=$i; done 2>&1 | grep -c "TESTS PASSED"
# Expected: 21 for full pass
```

## See Also

- **RTL Design:** [source/design/cpu/pipelined/ISA/ARCHITECTURE.md](../../../design/cpu/pipelined/ISA/ARCHITECTURE.md)
- **Single-Cycle Reference:** [source/verif/cpu/single_cycle/README.md](../single_cycle/README.md)
- **Multi-Cycle Reference:** [source/verif/cpu/multi_cycle/README.md](../multi_cycle/README.md)
- **Simulation Scripts:** [simu/README.md](../../../../simu/README.md)
