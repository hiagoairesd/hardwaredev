# Single-Cycle CPU Testbench Documentation

## Overview

The single-cycle CPU testbench (`cpu_sc_tb.sv`) provides a comprehensive test suite for validating the single-cycle MIPS-like processor design. The testbench implements 15 distinct test cases, ranging from basic register writes and memory access to complex programs such as Fibonacci sequences and overflow boundary conditions.

**Key Resources:**
- **RTL Design:** `source/design/cpu/single_cycle/`
- **Testbench:** `source/verif/cpu/single_cycle/cpu_sc_tb.sv`
- **Assembly Programs:** `source/verif/cpu/single_cycle/assembly/`
- **Simulation Script:** `simu/simulate`

## Running Tests

### Prerequisites

1. **Icarus Verilog** (or compatible Verilog simulator)
2. **SystemVerilog support** enabled in simulator

### Basic Test Execution

```bash
cd simu/
./simulate cpu_sc +test=<test_id> [+trace] [+trace_w]
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
| **default** | `integration.hex` | Integration (multiple instruction classes) |

### Trace Options

```bash
./simulate cpu_sc +test=1                      # Run test 1, no trace
./simulate cpu_sc +test=1 +trace_w             # Detailed trace (reg writes, branches)
./simulate cpu_sc +test=1 +trace               # Lightweight trace (PC, instr) + forces trace_w
```

## Test Suite Details

### Test 1: Basic Register Writes (`regs.hex`)

- **Purpose:** Validates basic register write paths.
- **PASS criteria:**

| Register | Expected Value |
|----------|---------------|
| R1 | 1 |
| R2 | 2 |
| R3 | 3 |

---

### Test 2: Basic SW/LW (`basic_swlw.hex`)

- **Purpose:** Validates the SW/LW basic path and addressing.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 42 |
| MEM[0] | 42 |
| R2 | 42 (loaded back from MEM[0]) |

---

### Test 3: Border SW/LW (`border_swlw.hex`)

- **Purpose:** Edge cases for immediate sign extension and memory boundary accesses.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 32767 (0x7FFF) |
| R2 | −32768 (0x8000) |
| R3 | −1 (0xFFFFFFFF) |
| MEM[255] | −1 |
| R4 | −1 |
| R5 | 0 |

---

### Test 4: R-Type ALU (`rtype.hex`)

- **Purpose:** Validates core ALU operations (ADD, SUB, AND, OR, SLT).
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

- **Purpose:** Validates J-type unconditional jump behavior.
- **PASS criteria:**

| Register | Expected | Notes |
|----------|---------|-------|
| R1 | 1 | Executed before jump |
| R2 | 0 | Skipped by jump |
| R3 | 0 | Skipped by jump |
| R4 | 4 | Executed at jump target |

---

### Test 6: BEQ (`beq.hex`)

- **Purpose:** Validates BEQ taken/not-taken paths and loop correctness.
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
| MEM[0] | 15 |
| MEM[4] | 240 |

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
| MEM[0] | 241 |
| MEM[4] | 4095 |

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
| MEM[0] | 305397760 |
| MEM[4] | 4294901760 |
| MEM[8] | 305441741 |

---

### Test 10: SLL (`sll.hex`)

- **Purpose:** Validates SLL shifting and edge conditions.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 1 |
| R2 | 16 (1 << 4) |
| R3 | 32 (1 << 5) |
| R4 | 240 (0x0F << 4) |
| R5 | 61440 (0x0F << 12) |
| MEM[0] | 16 |
| MEM[4] | 61440 |

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
| MEM[0] | 1073741824 |
| MEM[4] | 15 |

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
| MEM[0] | 13107 |

---

### Test 13: BLT (`blt.hex`)

- **Purpose:** Validates BLT (branch if less than) taken path.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| MEM[0] | 1 |
| MEM[1] | 1 |
| MEM[2] | 1 |

---

### Test 14: Fibonacci (`fibonacci.hex`)

- **Purpose:** Validates a longer loop-based program with multiple instructions and memory writes. Computes Fibonacci up to fib(20) = 4181.
- **PASS criteria (selected):**

| Signal | Expected |
|--------|---------|
| R1 | 0x0A18 (2584) |
| R2 | 0x1055 (4181) |
| R4 | 0x14 (20 iterations) |
| R7 | 1 |
| MEM[0..19] | Fibonacci sequence: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181 |
| MEM[30] | 1 (success flag) |
| MEM[31] | 0x1055 = 4181 (final value fib(20)) |

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
| MEM[30] | 1 | success flag |
| MEM[31] | 0x6D73E55F | last valid value fib(46) |
| MEM[32] | 0xB11924E1 | first overflow value fib(47) |

---

### Default: Integration Test (`integration.hex`)

- **Purpose:** Validates multiple instruction classes working together in a single program.
- **PASS criteria:**

| Signal | Expected |
|--------|---------|
| R1 | 10 |
| R2 | 15 |
| R3 | 65536 |
| R4 | 40 |
| R5 | 20 |
| R7 | 15 |
| R8 | 31 |
| R9 | 15 |
| R10 | 25 |
| R11 | 10 |
| R12 | 25 |
| R13 | 1 |
| R14 | 0 |
| MEM[0] | 25 |
| MEM[1] | 0 |

---

## Testbench Architecture

### Test Loader and Dispatcher

The testbench uses `task automatic pick_test(input integer test_id)` with a `case(test_id)` to load the selected program into instruction memory:

```systemverilog
task automatic pick_test(input integer test_id);
  begin
    case(test_id)
      1:  $readmemh("../source/verif/cpu/single_cycle/assembly/regs.hex",               DUT.instr_mem.mem);
      2:  $readmemh("../source/verif/cpu/single_cycle/assembly/basic_swlw.hex",         DUT.instr_mem.mem);
      ...
      15: $readmemh("../source/verif/cpu/single_cycle/assembly/fibonacci_overflow.hex", DUT.instr_mem.mem);
      default:
          $readmemh("../source/verif/cpu/single_cycle/assembly/integration.hex",        DUT.instr_mem.mem);
    endcase
  end
endtask
```

### Test Execution Flow

1. **Test selection** (from `+test=<id>` plusarg)
2. **Reset asserted** (`rst = 1`)
3. **Program load** via `pick_test(id)` into `DUT.instr_mem.mem` while reset is asserted
4. **Reset deasserted** (`rst = 0`)
5. **Run until HALT or timeout** (`max_cycles = 500`)
6. **Verification dispatch** via `case(id)` (e.g., `check_fibonacci()`, `check_integration()`)

### Trace Output Format

#### Lightweight Trace (`+trace`)
```
t=00010 pc=0 instr=20020005 opcode=08
t=00020 pc=1 instr=20030003 opcode=08
...
-> HALT detected @00500 (PC=0x0000002A)
```

#### Detailed Trace (`+trace_w`)
```
t=00010 | REGWRITE | R1 <= 0x00000001
t=00020 | MEMWRITE | mem[0] <= 0x0000002A
t=00030 | BRANCH taken -> pc_next=5
t=00040 | JUMP -> pc_next=12
...
```

## Assembly Program Format

Programs are stored as 32-bit hex values, one instruction per line, and loaded into instruction memory by word index (PC unit = 1 instruction):

```
20020001      # ADDI R2, R0, 1
20030002      # ADDI R3, R0, 2
000000FC      # HALT
```

**Instruction encoding (MIPS-like):**
- I-type: `[opcode:6][rs:5][rt:5][imm:16]`
- R-type: `[opcode:6][rs:5][rt:5][rd:5][shamt:5][funct:6]`
- J-type: `[opcode:6][addr:26]`

> **Memory addressing note:** data memory in `cpu_sc` is word-indexed. `sw rt, N(r0)` writes to `data_mem[N]`, not byte address `N*4`.

## Expected Test Results

**Default run (`./simulate cpu_sc`)**

```
----------------------- RUNNING INTEGRATION TESTS [default] ---------------
...
----------------------- TESTS PASSED -------------------------
```

**Manual full regression (tests 1–15):**

```
✓ Test  1 (regs)                PASS
...
✓ Test 15 (fibonacci_overflow)  PASS

Total: 15/15 PASS
```

## Debugging Tips

### Timeout (Program Never Halts)

**Symptoms:** Simulation runs past `max_cycles` (500) without asserting `halted`

**Likely causes:**
1. **Missing HALT instruction** in program hex file
2. **Infinite loop:** Branch condition always true, backward offset causes loop
3. **PC corruption:** Control logic sends PC to undefined location

**Debug steps:**
```bash
./simulate cpu_sc +test=<failed_id> +trace_w 2>&1 | tail -50
# Look for repeating PC values or impossible branch targets
```

### Write-Back to Wrong Register

**Symptoms:** Expected value in R1, but R2 was written instead

**Likely causes:**
1. **`regDst` signal wrong:** selects `rt` instead of `rd` for R-type
2. **`memToReg` wrong:** writes ALU result when should write mem data (or vice versa)

**Debug steps:**
```bash
./simulate cpu_sc +test=<failed_id> +trace_w | grep REGWRITE
# Verify correct register index and data value
```

### Wrong Memory Address

**Symptoms:** Data written to `mem[4]` instead of `mem[1]`

**Likely causes:**
1. **Byte vs. word addressing mismatch:** ALU computes byte address but memory expects word index
2. **Immediate not sign-extended:** Negative offset treated as large positive

**Debug steps:**
```bash
./simulate cpu_sc +test=<failed_id> +trace_w | grep MEMWRITE
# Verify address (mem index) matches expected word index
```

### Branch Not Taken When Expected

**Symptoms:** BEQ skips target, or BLT fires on equal values

**Likely causes:**
1. **Comparator policy:** signed vs. unsigned comparison for BLT
2. **Condition inverted:** BNE triggers on equality instead of inequality

**Debug steps:**
```bash
./simulate cpu_sc +test=<failed_id> +trace_w | grep BRANCH
# Verify branch direction matches expected taken/not-taken
```

## File Organization

```
hardwaredev/
├── source/
│   ├── verif/
│   │   ├── cpu/
│   │   │   ├── single_cycle/
│   │   │   │   ├── cpu_sc_tb.sv          # Main testbench
│   │   │   │   ├── README.md              # This documentation
│   │   │   │   ├── assembly/              # Single-cycle test programs
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
│   │   │   │   │   └── integration.hex    # Default: integration test
├── simu/
│   ├── simulate                           # Unified simulation script
```

## Integration Tips for CI/CD

### Run specific test
```bash
cd simu
./simulate cpu_sc +test=6
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run default mode (integration only)
```bash
cd simu
./simulate cpu_sc
echo $?  # Exit code 0 = PASS, non-zero = FAIL
```

### Run full regression
```bash
cd simu
for i in {1..15}; do
  echo "Running test $i"
  ./simulate cpu_sc +test=$i || exit 1
done
```

### Parse results for CI
```bash
cd simu
for i in {1..15}; do ./simulate cpu_sc +test=$i; done 2>&1 | grep -c "TESTS PASSED"
# Expected: 15 for full pass
```

## See Also

- **RTL Design:** [source/design/cpu/single_cycle/ARCHITECTURE.md](../design/cpu/single_cycle/ARCHITECTURE.md)
- **Multi-Cycle Reference:** [source/verif/cpu/multi_cycle/README.md](../multi_cycle/README.md)
- **Simulation Scripts:** [simu/README.md](../../simu/README.md)
