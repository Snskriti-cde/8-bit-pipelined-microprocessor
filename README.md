# 8-Bit Pipelined Microprocessor

Custom 8-bit, MIPS-inspired processor in Verilog. Built in two stages: a single-cycle datapath, then a 5-stage pipelined version with forwarding, hazard detection, and two branch predictors.

---

## 1. Specification

| Property | Value |
|---|---|
| Data width | 8 bits |
| Instruction width | 32 bits |
| Address width | 8 bits (256 × instr, 256 × data) |
| Registers | 32 × 8-bit, `$zero` hardwired, `$sp` = `0xFF` on reset |
| Formats | R-type, I-type, J-type |
| Pipeline | IF → ID → EX → MEM → WB |
| Hazard handling | EX/MEM + MEM/WB forwarding, load-use stall |
| Branch resolution | EX stage |
| Branch prediction | 2-entry bimodal + 16-entry BHT/BTB (standalone) |

---

## 2. Registers

| Number | Name | Usage |
|---|---|---|
| $0 | zero | Constant 0 |
| $1 | at | Assembler temporary |
| $2–$3 | v0–v1 | Function return values / expression evaluation |
| $4–$7 | a0–a3 | Function arguments |
| $8–$15 | t0–t7 | Temporaries |
| $16–$23 | s0–s7 | Saved temporaries |
| $24–$25 | t8–t9 | Temporaries |
| $26–$27 | k0–k1 | Reserved (OS kernel) |
| $28 | gp | Global pointer |
| $29 | sp | Stack pointer |
| $30 | fp | Frame pointer |
| $31 | ra | Return address |

- `$zero` (r0): reads always return 0; writes to it are dropped.
- `$sp` (r29): initialized to `0xFF` on reset — stack starts at top of memory and grows down.

## 3. Instruction Formats

```
R: [31:26] opcode(0x00) | [25:21] rs | [20:16] rt | [15:11] rd | [10:6] shamt | [5:0] funct
I: [31:26] opcode       | [25:21] rs | [20:16] rt | [15:8] 0   | [7:0]  imm8
J: [31:26] opcode       | [25:8]  0                            | [7:0]  address
```

## 4. Opcodes

| Mnemonic | Op | Mnemonic | Op | Mnemonic | Op |
|---|---|---|---|---|---|
| R-type | 0x00 | BNE | 0x05 | LW | 0x23 |
| J | 0x02 | ADDI | 0x08 | SW | 0x2B |
| JAL | 0x03 | SLTI | 0x0A | HLT | 0x3F |
| BEQ | 0x04 | ANDI/ORI/XORI | 0x0C/D/E | | |

## 5. Funct Codes (R-type)

| Mn | F | Mn | F | Mn | F | Mn | F |
|---|---|---|---|---|---|---|---|
| SLL | 00 | JR | 08 | ADD | 20 | AND | 24 |
| SRL | 02 | ROL | 10 | NOT | 21 | OR | 25 |
| SRA | 03 | ROR | 11 | SUB | 22 | XOR | 26 |
| | | INC/DEC | 12/13 | PASA | 23 | NOR/SLT | 27/2A |
| | | MUL/DIV | 18/1A | | | | |

- Branch offset = `target − (branch_addr + 1)`, encoded 8-bit two's complement, added to `PC+1` in hardware.
- Jump target (`J`/`JAL`) = absolute 8-bit address, placed directly in `instr[7:0]`.
- `JAL` additionally writes `PC+1` into `$ra` and sets `reg_dst = $ra`.
- `JR` writes no register; target = value in `rs`.

---

## 6. Phase 1 — Single-Cycle Modules

| Module | File | Function |
|---|---|---|
| ALU | `ALU/alu.v` | 18 ops (arith/logic/shift/rotate/mul/div), Z/N/C/V flags |
| ALU Control | alu_control.v` | `alu_op`+`funct` → 5-bit ALU code |
| Control Unit | control_unit.v` | `{opcode,funct}` → all datapath control signals |
| Register File | register_file.v` | 32×8-bit, 2R/1W, `$zero` hardwired |
| Program Counter | program_counter.v` | 8-bit, 4-way next-PC mux |
| Instruction Memory | instruction_memory.v` | 256×32-bit ROM |
| Data Memory | data_memory.v` | 256×8-bit RAM, sync write / async read |
| Branch Unit | branch_unit.v` | BEQ/BNE decision + branch/jump/JR targets |

**ALU** (`alu.v`, `alu_defs.vh`)
- Inputs: `a[7:0]`, `b[7:0]`, `shamt[4:0]`, `alu_control[4:0]`
- Outputs: `result[7:0]`, `flag_z`, `flag_n`, `flag_c`, `flag_v`, `less_than`, `carry`
- ADD/SUB/INC/DEC computed on a shared 9-bit adder (b inverted + carry-in for subtract) so carry/overflow fall out naturally
- `SLT` uses sign-aware compare (`a[7]^b[7]` selects between sign bit and difference sign, avoiding overflow errors)
- `SRA` is arithmetic (sign-preserving); `ROL`/`ROR` rotate `b` by `shamt[2:0]`
- `flag_z` is combinational from `result`; unused flag outputs are left open at the top level

**ALU Control** (`alu_control.v`)
- Inputs: `alu_op[2:0]` (from control unit), `funct[5:0]` (R-type only)
- `alu_op` classes: `ADD, SUB, AND, OR, XOR, SLT` pass straight through; `RTYPE (111)` re-decodes by `funct`
- Output: 5-bit `alu_control` matching `alu_defs.vh` codes

**Control Unit** (`control_unit.v`)
- Inputs: `opcode[5:0]`, `funct[5:0]`
- Outputs: `reg_dst[1:0]`, `alu_src`, `mem_to_reg[1:0]`, `branch`, `jump`, `jal`, `jump_reg`, `reg_write`, `mem_read`, `mem_write`, `alu_op[2:0]`, `halt`
- `reg_dst`: `00`=rt (I-type), `01`=rd (R-type), `10`=`$ra` (JAL)
- `mem_to_reg`: `00`=ALU result, `01`=loaded data, `10`=`PC+1`
- `JR` (funct `0x08`) detected inside the `OPC_R` case: sets `jump_reg` only, no `reg_write`
- All outputs default low/zero before the `case`, avoiding inferred latches

**Register File** (`register_file.v`)
- Parameters: `data_width=8`, `num_regs=32`
- Ports: 2 async read (`read_reg_1`, `read_reg_2`), 1 sync write (`write_reg`, `write_data`, `reg_write`)
- Reset zeroes all 32 registers, then sets `regs[29] = 0xFF` ($sp)
- Write is blocked when `write_reg == 0`, protecting `$zero`

**Program Counter** (`program_counter.v`, module `Program_Counter`)
- Ports: `Clock`, `Reset`, `Pc_Sel[1:0]`, `Jr_Target`, `Jump_Target`, `Branch_Target` → `Pc[7:0]`, `Pc_Next[7:0]`
- `Pc_Next = Pc + 1` (combinational, always available for link/fall-through use)
- `Pc_Sel` mux: `00`=`Pc_Next`, `01`=`Branch_Target`, `10`=`Jump_Target`, `11`=`Jr_Target`
- Synchronous reset to `0`

**Instruction Memory** (`instruction_memory.v`, module `Instruction_Memory`)
- 256 × 32-bit array, combinationally addressed (`Instr = Instr_Array[Address]`)
- Contents currently set only by two hardcoded debug words in the `initial` block (see §12)

**Data Memory** (`data_memory.v`)
- Parameters: `DATA_WIDTH=8`, `ADDR_WIDTH=8`, `MEM_DEPTH=256`
- Synchronous write on `memWrite` at `posedge clk`; synchronous `rst` clears the whole array
- Read is combinational: `readData = memory[address]` when `memRead`, else `0`

**Branch Unit** (`branch_unit.v`)
- Inputs: `branch`, `bne`, `jump`, `jump_reg`, `flag_z`, `pc_plus1`, `imm8`, `rs_val`
- `branch_taken = branch & (flag_z ^ bne)` — one circuit serves both `BEQ` (`bne=0`) and `BNE` (`bne=1`)
- `branch_target = pc_plus1 + imm8`, `jump_target = imm8`, `jr_target = rs_val`
- `pc_sel` priority (highest first): `jump_reg` → `jump` → `branch_taken` → sequential

---

## 7. Phase 2 — 5-Stage Pipeline

| Stage | Function |
|---|---|
| IF | Fetch instruction, compute `PC+1` |
| ID | Decode, register read, hazard check |
| EX | Forwarding mux → ALU → branch resolution |
| MEM | Load/store |
| WB | Write-back mux: ALU / MEM / `PC+1` (JAL) |

**IF**
- PC address = `ex_take_branch ? ex_target_addr : PC+1`
- `pc_write_enable`: forced high on a taken branch (so redirect always lands), otherwise `~hazard_stall & ~id_halt`
- Squashed instruction (on a taken branch) is replaced with a `32'd0` NOP before latching into IF/ID

**ID**
- Splits `opcode`, `rs`, `rt`, `rd`, `shamt`, `funct`, `imm` out of the fetched word
- Drives `control_unit` and reads both register-file ports in the same cycle
- `hazard_detection_unit` compares this instruction's `rs`/`rt` against the load sitting in ID/EX

**EX**
- `forwarding_unit` computes `forwardA`/`forwardB` from EX/MEM and MEM/WB destinations
- Operand mux: `00`=ID/EX register value, `10`=EX/MEM result, `01`=MEM/WB result
- `alu_control` refines `alu_op`+`funct` into the ALU opcode; ALU executes
- `branch_unit` resolves branch/jump/JR using the (forwarded) `rs` value and the ALU's zero flag

**MEM**
- Data memory addressed by the ALU result; `mem_read`/`mem_write` from the control word carried down the pipeline

**WB**
- `wb_final_data` mux: `01`=loaded memory word, `10`=`PC+1` (JAL link), else ALU result
- `halt` output = `wb_halt`, i.e. only asserted once `HLT` itself reaches WB

**Hazards**
- Structural — none (separate I-mem/D-mem)
- Data — `HAZARD/forwarding_unit.v`: EX/MEM and MEM/WB → EX operand muxes; EX/MEM takes priority over MEM/WB on a tie; `rd==0` never triggers forwarding
- Load-use — `HAZARD/hazard_detection_unit.v`: `stall = (id_ex is a load) & (id_ex_rt matches if_id_rs or if_id_rt)`; asserts a 1-cycle stall, freezing PC/IF-ID and bubbling ID/EX
- Control — resolved in EX; `flush_if_id` / `flush_id_ex` squash the 2 younger instructions (currently in IF and ID) on any taken branch/jump/JR; `flush_id_ex` also covers the load-use bubble

**Halt:** decoded in ID, freezes fetch immediately (`id_halt` blocks `pc_write_enable`), but the top-level `halt` output only asserts once `HLT` reaches WB — every instruction already in flight drains first.

---

## 8. Branch Predictors (standalone, not yet wired into `cpu.v`)

| Module | Design |
|---|---|
| `branch_predictor_2x2.v` | 2 entries × 2-bit saturating counter, indexed by PC[2] |
| `branch_predictor_btb16.v` | 16-entry BHT (2-bit counters) + 16-entry tagged BTB; predicts in IF, resolves/updates in EX, generates mispredict/flush |

**`branch_predictor_2x2`**
- 2-bit saturating counter per entry: `00` strong-NT → `01` weak-NT → `10` weak-T → `11` strong-T
- Row select = `pc[2]`; prediction = counter MSB
- One-cycle `update_en` pulse increments/decrements the counter toward the actual outcome

**`branch_predictor_btb16`**
- `bht`: 16 × 2-bit counters, indexed `pc[5:2]`; read-during-write forwarding so a same-cycle re-fetch sees the fresh count
- `btb`: 16-entry, tagged, direct-mapped target cache; `hit = valid[idx] & (tag[idx]==pc_tag)`
- `branch_predictor_unit`: predicts `taken = btb_hit & bht_prediction` in IF; carries the prediction down to EX via shadow latches; `mispredict` fires if the resolved outcome or target disagrees with the carried prediction; `flush_if`/`flush_id` squash on a miss
- A predicted-taken hit redirects fetch immediately in IF (0-bubble); a misprediction still costs the same 2-cycle squash as the non-predicting baseline

---

## 9. Toolchain

- `ASM/assembler.py` — 2-pass Python assembler (labels, hex/dec immediates, `LW rt, imm(rs)` syntax)
- `ASM/factorial.asm` — recursive factorial(5): JAL/JR, stack push/pop, MUL
- `ASM/sort.asm` — bubble sort, 5 elements: nested loops, SLT compare, conditional SW swap
- `ASM/program.hex`, `instruction_memory.mem` — pre-assembled output

```bash
cd RTL/ASM && python3 assembler.py
```

- Pass 1: scans source, records label → address in a symbol table (comments after `#`/`;` stripped)
- Pass 2: re-encodes each line, resolving `J`/`JAL` targets and `BEQ`/`BNE` PC-relative offsets from that table
- Accepts register names with or without `$` (`t0` or `$t0`) and immediates in hex or decimal

---

## 10. Repository Structure

```
.
├── README.md
├── LICENSE
└── RTL/
    ├── ALU/                alu.v, alu_defs.vh
    ├── CONTROL/            control_unit.v, alu_control.v, branch_unit.v
    ├── CPU/                cpu.v (top-level pipeline)
    ├── HAZARD/             forwarding_unit.v, hazard_detection_unit.v
    ├── MEMORY/             instruction_memory.v, data_memory.v
    ├── REGISTER/           register_file.v, program_counter.v
    ├── BRANCH_PREDICTOR/   branch_predictor_2x2.v, branch_predictor_btb16.v
    ├── ASM/                assembler.py, factorial.asm, sort.asm,
    │                       program.hex, instruction_memory.mem
    └── TEST_BENCH/         alu_tb.v, control_unit_tb.v, branch_unit_tb.v,
                            pc_tb.v, register_file_tb.v, data_memory_tb.v,
                            forwarding_unit_tb.v, instruction_memory_tb.v,
                            cpu_tb.v
```

---

## 11. Running Tests

```bash
iverilog -o sim -I RTL/ALU RTL/ALU/alu.v RTL/TEST_BENCH/alu_tb.v && vvp sim
iverilog -o sim RTL/CONTROL/control_unit.v RTL/TEST_BENCH/control_unit_tb.v && vvp sim
iverilog -o sim RTL/CONTROL/branch_unit.v RTL/TEST_BENCH/branch_unit_tb.v && vvp sim
iverilog -o sim RTL/REGISTER/program_counter.v RTL/TEST_BENCH/pc_tb.v && vvp sim
iverilog -o sim RTL/MEMORY/data_memory.v RTL/TEST_BENCH/data_memory_tb.v && vvp sim
iverilog -o sim RTL/HAZARD/forwarding_unit.v RTL/TEST_BENCH/forwarding_unit_tb.v && vvp sim
# instruction_memory_tb reads program.hex via relative path — run from RTL/ASM/
cd RTL/ASM && iverilog -o /tmp/sim ../MEMORY/instruction_memory.v ../TEST_BENCH/instruction_memory_tb.v && vvp /tmp/sim
```

---



## License

MIT — see [LICENSE](LICENSE).
