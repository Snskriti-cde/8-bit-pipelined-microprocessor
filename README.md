# Pipelined CPU (Verilog)

A pipelined processor implemented in Verilog, including a custom instruction
set assembler, hazard detection, data forwarding, and two branch predictor
variants (2-bit 2-level, and BTB-based).

## Structure

```
RTL/
├── ALU/                Arithmetic Logic Unit
├── CONTROL/             Control unit, ALU control, branch unit
├── CPU/                 Top-level pipelined CPU
├── HAZARD/              Hazard detection + forwarding unit
├── MEMORY/               Instruction memory, data memory
├── REGISTER/             Register file, program counter
├── BRANCH_PREDICTOR/     2-bit 2-level and BTB-based predictors
├── ASM/                  Assembler + sample assembly programs
└── TEST_BENCH/           Testbenches for every module
```

## Modules

| File | Description |
|---|---|
| `CPU/cpu.v` | Top-level pipelined CPU |
| `ALU/alu.v` / `alu_defs.vh` | Arithmetic Logic Unit |
| `CONTROL/alu_control.v` | ALU operation decode |
| `CONTROL/control_unit.v` | Main control unit |
| `CONTROL/branch_unit.v` | Branch resolution |
| `HAZARD/forwarding_unit.v` | Data forwarding (hazard resolution) |
| `HAZARD/hazard_detection_unit.v` | Pipeline hazard/stall detection |
| `REGISTER/register_file.v` | Register file |
| `REGISTER/program_counter.v` | Program counter |
| `MEMORY/instruction_memory.v` | Instruction memory |
| `MEMORY/data_memory.v` | Data memory |
| `BRANCH_PREDICTOR/branch_predictor_2x2.v` | 2-bit, 2-level branch predictor |
| `BRANCH_PREDICTOR/branch_predictor_btb16.v` | 16-entry BTB-based branch predictor |

## Assembly (ASM/)

- `assembler.py` — custom assembler for this ISA
- `factorial.asm`, `sort.asm` — sample programs
- `program.hex`, `instruction_memory.mem` — assembled output, loaded by instruction memory

## Running tests

Each module has a matching testbench in `TEST_BENCH/`. Run an individual
testbench with your simulator of choice, e.g. with Icarus Verilog:

```bash
iverilog -o sim_alu -I RTL/ALU RTL/ALU/alu.v RTL/TEST_BENCH/alu_tb.v
vvp sim_alu
```

## License

MIT — see [LICENSE](LICENSE).
