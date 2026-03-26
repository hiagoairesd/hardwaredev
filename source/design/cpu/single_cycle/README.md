# Single-Cycle CPU

## Overview

Implementação de uma CPU MIPS-like de 32 bits com datapath single-cycle.
Cada instrução é executada em um único ciclo de clock (fetch, decode, execute, memory, write-back no mesmo ciclo combinacional).

## Design Files

Pasta: [source/design/cpu/single_cycle](.)

- `cpu_sc.v`: integração top-level da CPU single-cycle
- `control_unit.v`: decodificação de instruções e geração de sinais de controle
- `instr_mem.v`: memória de instruções
- `data_mem.v`: memória de dados
- Reuso de blocos comuns em [source/design/cpu/common](../common):
  - `alu.v`
  - `register_file.v`

## Architecture Document

Descrição arquitetural completa:
- [source/design/cpu/single_cycle/ISA/ARCHITECTURE.md](ISA/ARCHITECTURE.md)

## Verification

Testbenches e programas de teste:
- Pasta: [source/verif/cpu/single_cycle](../../../verif/cpu/single_cycle)
- Arquivos principais:
  - `cpu_sc_tb.sv`
  - `control_unit_tb.sv`
  - `instr_mem_tb.sv`
  - `data_mem_tb.sv`
  - `assembly/`

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

A partir de [simu](../../../../simu):

```bash
./simulate cpu_sc
./simulate cpu_sc +test=1
./simulate cpu_sc +test=1 +trace
./simulate cpu_sc +test=1 +trace_w
```

Também é possível rodar módulos individualmente:

```bash
./simulate alu
./simulate control_unit
./simulate register_file
```

### Quick regression

```bash
for i in {1..15}; do
  echo "Running test $i"
  (cd ../../../../simu && ./simulate cpu_sc +test=$i) || echo "Test $i failed"
done
```

## Scope da ISA (resumo)

- R-Type: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`
- I-Type: `ADDI`, `ANDI`, `ORI`, `LUI`, `LW`, `SW`, `BEQ`, `BNE`, `BLT`
- J-Type: `JUMP`
- System: `HALT`

Para detalhes de codificação, política de imediato, fluxo de PC e contratos arquiteturais, consultar o arquivo de arquitetura.
