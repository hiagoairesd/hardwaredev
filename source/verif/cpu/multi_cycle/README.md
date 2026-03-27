# Multi-Cycle CPU Testbench Documentation

## Overview

The multi-cycle CPU testbench (`cpu_mc_tb.sv`) provides a comprehensive test suite for validating the multi-cycle MIPS-like processor design. The testbench implements 20 distinct test cases, ranging from basic instruction validation to complex integration scenarios with loops, branches, and interleaved memory access.

**Key Resources:**
- **RTL Design:** `source/design/cpu/multi_cycle/`
- **Testbench:** `source/verif/cpu/multi_cycle/cpu_mc_tb.sv`
- **Assembly Programs:** `source/verif/cpu/multi_cycle/assembly/`
- **Simulation Script:** `simu/simulate`

## Running Tests

### Prerequisites

1. **Icarus Verilog** (or compatible Verilog simulator)
2. **SystemVerilog support** enabled in simulator

### Basic Test Execution

```bash
cd simu/
./simulate cpu_mc +test=<test_id> [+trace] [+trace_w] [+trace_m]
```

### Test Selection Options

| Test ID | Name | Cycles | Purpose |
|---------|------|--------|---------|
| 1–6 | Basic instruction set | ~100–200 | Fundamental R-type, branches, immediates |
| 7–11 | Shifts and complex immediates | ~150–250 | SLL, SRL, ORI, LUI |
| 12–15 | Branches and recursion | ~400–1000 | BNE, BLT, Fibonacci patterns |
| 16–19 | Edge cases | ~200–500 | Zero register, halt placement, accumulators |
| 20 | Integration (comprehensive) | ~2900 | 46-instruction program with nested loops |
| **default** | Integration only (`test=20`) | ~2900 | Runs `integration.hex` |

### Trace Options

```bash
./simulate cpu_mc +test=1                      # Run test 1, no trace
./simulate cpu_mc +test=1 +trace_w             # Detailed trace (reg writes, branches)
./simulate cpu_mc +test=1 +trace               # Lightweight trace (PC, instr)
./simulate cpu_mc +test=1 +trace_m             # Microarchitectural trace (ALU, regfile)
./simulate cpu_mc +test=1 +trace_w +dump=1     # Trace + VCD dump
```

## Test Suite Details

### Tests 1–3: Basic R-Type and Branch Instructions

**Test 1: ADD**
- **Program:** Simple ADD operation
- **Cycles:** ~32
- **Validation:** Check register writeback and ALU result

**Test 2: SUB**
- **Program:** Subtraction with register writeback
- **Cycles:** ~32
- **Validation:** Negative result handling

**Test 3: BEQ (Branch if Equal)**
- **Program:** Conditional branch taken and not-taken
- **Cycles:** ~50
- **Validation:** PC update for both branch paths

### Tests 4–6: Logic Operations and Basic Branches

**Test 4: AND**
- **Program:** Bitwise AND operation
- **Cycles:** ~32
- **Validation:** Logic result verification

**Test 5: OR**
- **Program:** Bitwise OR operation
- **Cycles:** ~32
- **Validation:** Logic result verification

**Test 6: JUMP (J-type)**
- **Program:** Unconditional jump with address calculation
- **Cycles:** ~24
- **Validation:** PC jump to target address

### Tests 7–9: Immediate Operations (Part 1)

**Test 7: ADDI (Add Immediate)**
- **Program:** Addition with sign-extended immediate
- **Cycles:** ~32
- **Validation:** Sign extension of negative immediates

**Test 8: ANDI (AND Immediate)**
- **Program:** AND with zero-extended immediate
- **Cycles:** ~32
- **Validation:** Zero-extension policy verification

**Test 9: ORI (OR Immediate)**
- **Program:** OR with zero-extended immediate
- **Cycles:** ~32
- **Validation:** Zero-extension behavior

### Tests 10–11: Shift Operations

**Test 10: SLL (Shift Left Logical)**
- **Program:** Register shift with shamt field
- **Cycles:** ~32
- **Validation:** Shift amount selection from `instr[10:6]`

**Test 11: SRL (Shift Right Logical)**
- **Program:** Logical right shift
- **Cycles:** ~32
- **Validation:** Zero-fill on right shift

### Tests 12–13: Load/Store and Additional Immediates

**Test 12: LW (Load Word)**
- **Program:** Memory read with address calculation
- **Cycles:** ~72 (5-cycle LW pipeline)
- **Validation:** Data memory access and writeback

**Test 13: SW (Store Word)**
- **Program:** Memory write with address calculation
- **Cycles:** ~64 (4-cycle SW pipeline)
- **Validation:** Data written to correct memory address

### Tests 14–15: Complex Branches and Recursion

**Test 14: BNE (Branch if Not Equal)**
- **Program:** BNE taken and not-taken paths
- **Cycles:** ~50
- **Validation:** Inverse of BEQ condition

**Test 15: Fibonacci (Recursive)**
- **Program:** Recursive-style Fibonacci accumulation
- **Cycles:** ~400
- **Validation:** Nested loops, register persistence, memory accumulation

### Test 15b: Fibonacci Overflow

**Test 15b: Fibonacci with Overflow**
- **Program:** Fibonacci with wrap-around at 32-bit boundary
- **Cycles:** ~400
- **Validation:** Overflow behavior (no exception, just wraps)

### Tests 16–19: Edge Cases

**Test 16: Zero Register (R0)**
- **Program:** Attempt to write to `R0`
- **Cycles:** ~32
- **Validation:** `R0` remains zero; write is ignored

**Test 17: HALT Placement**
- **Program:** HALT in different positions (early vs. late)
- **Cycles:** ~50 (varies)
- **Validation:** Program correctly terminates at HALT

**Test 18: Loop Counter**
- **Program:** Simple loop with counter update (BNE backward)
- **Cycles:** ~150
- **Validation:** Loop executes correct number of iterations

**Test 19: Array Sum**
- **Program:** Accumulator pattern over array elements
- **Cycles:** ~200
- **Validation:** Memory read, accumulate, store in loop

### Test 20: Comprehensive Integration Test

**Test 20: Full Integration (46-instruction program)**

This is the primary integration test covering all instruction classes and realistic execution patterns.

#### Program Structure

```
────────────────────────────────────────────────────────
  INIT PHASE (Instr 0–15)
────────────────────────────────────────────────────────
  Set up registers:
    R1 ← 0          (accumulator)
    R2 ← 1          (loop counter increment)
    R3 ← 6          (loop bound)
    R5 ← 0x123400f0 (pattern test)
    R15 ← 0x200     (memory pointer: data region start)
  
────────────────────────────────────────────────────────
  LOOP PHASE (Instr 16–27) × 6 iterations
────────────────────────────────────────────────────────
  [0] R1 ← R1 + R2        (accumulate: 0→1→3→6→10→15)
  [1] SW R1 @ [R15]       (store to mem[0x200 + 0/4/8/...])
  [2] LW R1 @ [R15]       (verify load)
  [3] BEQ (not taken here) 
  [4] ADDI (skipped in loop)
  [5] BNE with -12-word offset (loop back to [0] for iterations 1–5)
      Last iteration (6): continue forward
  
────────────────────────────────────────────────────────
  BRANCH TEST PHASE (Instr 28–40)
────────────────────────────────────────────────────────
  Test each branch type with taken and not-taken paths:
    • BEQ taken (when Rs == Rt)
    • BEQ not taken
    • BNE taken
    • BNE not taken
    • BLT taken
    • BLT not taken
  
────────────────────────────────────────────────────────
  CLEANUP PHASE (Instr 41–45)
────────────────────────────────────────────────────────
  [41] Final SW operation
  [42] Final LW operation
  [43] JUMP to [46] (skip next instruction)
  [44] Skipped instruction
  [45] HALT (execution terminates)
```

#### Memory Result After Execution

| Address | Value | Meaning |
|---------|-------|---------|
| `0x80` (mem[32]) | 1 | Iteration 1: accumulation |
| `0x84` (mem[33]) | 3 | Iteration 2: accumulation |
| `0x88` (mem[34]) | 6 | Iteration 3: accumulation |
| `0x8c` (mem[35]) | 10 | Iteration 4: accumulation |
| `0x90` (mem[36]) | 15 | Iteration 5: accumulation |
| `0x94` (mem[37]) | 0xffffffff | Pattern test value |
| `0x98` (mem[38]) | 0 | Cleanup write |

#### Register State After Execution

| Register | Expected Value | Verification |
|----------|---------------|--------------|
| R1 | 15 | Final accumulation sum (1+2+3+4+5) |
| R2 | 6 | Loop counter after 6 iterations |
| R3 | 6 | Loop bound (unchanged) |
| R5 | 0x123400f0 | Pattern (unchanged) |
| R15 | 0x218 | Memory pointer after 6 increments (4 bytes each) |

#### Branch Coverage Matrix

The integration test validates all branch conditions:

| Branch Type | Path 1 (Taken) | Path 2 (Not-Taken) | Coverage |
|-------------|----------------|-------------------|----------|
| BEQ | `instr[19]: Rs==Rt` | `instr[28]: Rs≠Rt` | ✓ Both |
| BNE | `instr[21]: Rs≠Rt (loop 1–5)` | `instr[34]: Rs==Rt` | ✓ Both |
| BLT | `instr[23]: Rs<Rt (loop iter)` | `instr[30]: Rs!<Rt` | ✓ Both |
| JUMP | `instr[42]: unconditional` | N/A | ✓ Executed |

#### Key Validation Assertions

The testbench (`integration_test()` function) verifies:

1. **Register state** (10 registers: R1–R5, R15, etc.)
2. **Memory accumulation** (7 data locations: mem[32]–mem[38])
3. **Branch decision logs** (ensuring branches took expected paths)
4. **Final PC** (should reach HALT at instruction 45)

**Total assertions: 30+**

---

## Testbench Architecture

### Test Loader and Dispatcher

The testbench uses `task automatic pick_test(input integer test_id)` with a `case(test_id)` to load the selected program:

```systemverilog
task automatic pick_test(input integer test_id);
  begin
    case(test_id)
      1:  $readmemh("../source/verif/cpu/multi_cycle/assembly/regs.hex", DUT.memory.mem);
      2:  $readmemh("../source/verif/cpu/multi_cycle/assembly/basic_swlw.hex", DUT.memory.mem);
      ...
      20: $readmemh("../source/verif/cpu/multi_cycle/assembly/integration.hex", DUT.memory.mem);
      default:
        $readmemh("../source/verif/cpu/multi_cycle/assembly/integration.hex", DUT.memory.mem);
    endcase
  end
endtask
```

### Test Execution Flow

1. **Test selection** (from `+test=<id>` plusarg)
2. **Reset asserted** (`rst = 1`)
3. **Program load** via `pick_test(id)` while reset is asserted
4. **Reset deasserted** (`rst = 0`)
5. **Run until HALT or timeout** (`max_cycles`)
6. **Verification dispatch** with `case(id)` (e.g., `regs_test()`, `integration_test()`)

### Trace Output Format

#### Lightweight Trace (`+trace`)
```
t=00010 | pc=00000000 instr=20020005 opcode=000000 (ADDI) 
t=00020 | pc=00000004 instr=20020006 opcode=001000 → ADDI dispatched
...
-> HALT detected @00500 (PC=0x000000AC)
```

#### Detailed Trace (`+trace_w`)
```
t=00010 | REGWRITE | R1 <= 0x00000005
t=00020 | MEMWRITE | mem[0x80] <= 0x00000015
t=00030 | BRANCH taken -> pc_next=0x00000030
t=00040 | JUMP -> pc_next=0x00000048
...
```

#### Microarchitectural Trace (`+trace_m`)
```
t=00010 | ALU: 0x5 + 0x3 = 0x8 (aluControl=010)
t=00020 | RF: rd=R1, wdata=0x8, regWrite=1
t=00030 | MEM: addr=0x80, data_in=0x15, we=1
...
```

## Assembly Program Format

Programs are stored as 32-bit hex values, one per line (no line limits):

**File:** `assembly/integration.hex`
```
3C020000      # ADDI R2, R0, 0
20020000      # ADDI R2, R0, 0
...
000000FF      # HALT
```

**Instruction encoding follows MIPS:** 
- I-type: `[opcode:6][rs:5][rt:5][imm:16]`
- R-type: `[opcode:6][rs:5][rt:5][rd:5][shamt:5][funct:6]`
- J-type: `[opcode:6][addr:26]`

## Expected Test Results

**Default run (`./simulate cpu_mc`)**

```
----------------------- RUNNING INTEGRATION TESTS [20/default] ---------------
...
----------------------- TESTS PASSED -------------------------
```

**Manual full regression (tests 1–20):**

```
✓ Test  1 (ADD)              PASS @ cycle 32
...
✓ Test 20 (Integration)      PASS @ cycle 2965

Total: 20/20 PASS
```

## Debugging Tips

### Timeout (Program Never Halts)

**Symptoms:** Simulation runs past `max_cycles` without hitting HALT

**Likely causes:**
1. **Missing HALT instruction** in program hex file
2. **Infinite loop:** Branch condition always true, backward offset causes loop
3. **PC corruption:** Control logic sends PC to undefined location

**Debug steps:**
```bash
./simulate cpu_mc +test=<failed_id> +trace_w 2>&1 | tail -50
# Look for repeating instruction patterns or impossible PC values
```

### Write-Back to Wrong Register

**Symptoms:** Expected value in R1, but R2 was written instead

**Likely causes:**
1. **regDst signal wrong:** Might select `rt` instead of `rd` for R-type
2. **ALU result not latched:** Writeback occurred before `alu_reg` updated

**Debug steps:**
```bash
./simulate cpu_mc +test=<failed_id> +trace_w | grep REGWRITE
# Verify correct register index (wa3) and data value
```

### Wrong Memory Address

**Symptoms:** Data written to mem[0x100] instead of mem[0x80]

**Likely causes:**
1. **Immediate not sign-extended:** Negative offset treated as large positive
2. **Address calculation misaligned:** ALU offset not applied correctly

**Debug steps:**
```bash
./simulate cpu_mc +test=<failed_id> +trace_w | grep MEMWRITE
# Verify address calculation: base + offset
```

### Branch Not Taken When Expected

**Symptoms:** Program skips over expected branch target

**Likely causes:**
1. **Comparator bug:** BEQ checks signed vs. unsigned incorrectly
2. **Condition backwards:** BNE triggers on equality instead of inequality

**Debug steps:**
```bash
./simulate cpu_mc +test=<failed_id> +trace_w | grep BRANCH
# Verify condition (Rs==Rt for BEQ, Rs<Rt for BLT, etc.)
```

## File Organization

```
hardwaredev/
├── source/
│   ├── verif/
│   │   ├── cpu/
│   │   │   ├── multi_cycle/
│   │   │   │   ├── cpu_mc_tb.sv          # Main testbench
│   │   │   │   ├── README.md              # This documentation
│   │   │   │   ├── assembly/              # Multi-cycle test programs
│   │   │   │   │   ├── regs.hex           # Test 1
│   │   │   │   │   ├── basic_swlw.hex     # Test 2
│   │   │   │   │   ├── border_swlw.hex    # Test 3
│   │   │   │   │   ├── rtype.hex          # Test 4
│   │   │   │   │   ├── jump.hex           # Test 5
│   │   │   │   │   ├── beq.hex            # Test 6
│   │   │   │   │   ├── andi.hex           # Test 7
│   │   │   │   │   ├── ori.hex            # Test 8
│   │   │   │   │   ├── lui.hex            # Test 9
│   │   │   │   │   ├── sll.hex            # Test 10
│   │   │   │   │   ├── srl.hex            # Test 11
│   │   │   │   │   ├── bne.hex            # Test 12
│   │   │   │   │   ├── blt.hex            # Test 13
│   │   │   │   │   ├── fibonacci.hex      # Test 14
│   │   │   │   │   ├── fibonacci_overflow.hex # Test 15
│   │   │   │   │   ├── zero_register_protection.hex # Test 16
│   │   │   │   │   ├── halt_placement.hex # Test 17
│   │   │   │   │   ├── loop_counter.hex   # Test 18
│   │   │   │   │   ├── array_sum.hex      # Test 19
│   │   │   │   │   ├── integration.hex    # Test 20 / default
│   │   │   │   │   ├── test_mem_invasion.hex # Test 100
│   │   │   │   │   └── test_instr_overflow.hex # Test 101
├── simu/
│   ├── simulate                           # Unified simulation script
```

## Integration Tips for CI/CD

### Run specific test
```bash
cd simu
./simulate cpu_mc +test=20
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run default mode (integration only)
```bash
cd simu
./simulate cpu_mc
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run full regression
```bash
cd simu
for i in {1..20}; do
  echo "Running test $i"
  ./simulate cpu_mc +test=$i || exit 1
done
```

### Parse results for CI
```bash
cd simu
for i in {1..20}; do ./simulate cpu_mc +test=$i; done 2>&1 | grep -c "TESTS PASSED"
# Expected: 20 for full pass
```

## See Also

- **RTL Design:** [source/design/cpu/multi_cycle/ARCHITECTURE.md](../design/cpu/multi_cycle/ARCHITECTURE.md)
- **Single-Cycle Reference:** [source/verif/cpu/single_cycle/README.md](../single_cycle/README.md)
- **Simulation Scripts:** [simu/README.md](../../simu/README.md)
