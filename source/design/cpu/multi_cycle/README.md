# Multi-Cycle CPU

## Overview

Implementação de uma CPU MIPS-like de 32 bits com controle multi-cycle baseado em FSM.
As instruções são divididas em múltiplos estados, reutilizando ALU e memória em ciclos distintos.

## Design Files

Pasta: [source/design/cpu/multi_cycle](.)

- `cpu_mc.v`: integração top-level da CPU multi-cycle
- `control_unit.v`: unidade de controle em máquina de estados
- `memory.v`: memória unificada (instrução + dados)
- Reuso de blocos comuns em [source/design/cpu/common](../common):
  - `alu.v`
  - `register_file.v`

## Architecture Document

Descrição arquitetural completa:
- [source/design/cpu/multi_cycle/ISA/ARCHITECTURE.md](ISA/ARCHITECTURE.md)

## Verification

Testbenches e programas de teste:
- Pasta: [source/verif/cpu/multi_cycle](../../../verif/cpu/multi_cycle)
- Arquivos principais:
  - `cpu_mc_tb.sv`
  - `control_unit_tb.sv`
  - `memory_tb.sv`
  - `assembly/`
- Guia de testes:
  - [source/verif/cpu/multi_cycle/README.md](../../../verif/cpu/multi_cycle/README.md)

## Simulation

A partir de [simu](../../../../simu):

```bash
./simulate cpu_mc
./simulate cpu_mc +test=1
./simulate cpu_mc +test=1 +trace
./simulate cpu_mc +test=1 +trace_w
```

## FSM de execução (resumo)

Estados principais:
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

Fluxos típicos:
- R-type: `FETCH -> DECODE -> EXECUTE -> ALU_WRITEBACK`
- LW: `FETCH -> DECODE -> MEM_ADR -> MEM_READ -> MEM_WRITEBACK`
- SW: `FETCH -> DECODE -> MEM_ADR -> MEM_WRITE`

Para detalhes de sinais de controle (`IorD`, `PCSrc`, `PCEn`, `aluSrcA/B`, etc.), consultar o arquivo de arquitetura.
