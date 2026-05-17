# CSE 141L Milestone 3 Add-on

This add-on is intended to be copied into the Milestone 2 report after updating the report title to "CSE 141L Milestone 3". The component specification remains in the main report; this file focuses on the Milestone 3 software deliverables and the changes made since Milestone 2.

# 6. Software - provide as attachments

## 6.a. Software/Hardware Integration

For Milestone 3, we completed the true ARIA software path. The submitted programs are real ARIA assembly programs that are assembled into 9-bit instruction ROM images and executed by the SystemVerilog CPU.

The software flow is:

```text
software/programN.asm
  -> software/aria_asm.py
  -> software/programN.mem
  -> rtl/aria_imem.sv
  -> rtl/DUT.sv
  -> rtl/dat_mem.sv outputs checked by exported benches
```

The exported testbenches preload operands into `D1.dm.core[0:63]`. The ARIA CPU then executes the assembled program from instruction memory and writes results back into the required data-memory output addresses.

Program selection is controlled by compile-time defines:

- `-DPROG1` loads `software/program1.mem`
- `-DPROG2` loads `software/program2.mem`
- `-DPROG3` loads `software/program3.mem`

All generated `.mem` files contain exactly 1024 lines of 9-bit binary machine code. Unused ROM entries are filled with `HALT`.

## 6.b. Assembler

The assembler is implemented in:

```text
software/aria_asm.py
```

It accepts ARIA assembly and emits a 1024-word machine-code image plus an optional listing file. The CLI is:

```sh
python3 software/aria_asm.py software/program1.asm -o software/program1.mem --listing software/program1.lst
```

The assembler supports:

- All real ARIA ALU instructions: `ADD`, `ADDC`, `SUB`, `SUBB`, `AND`, `OR`, `XOR`, `CMP`, `LSL`, `LSR`, `ROL`, `ROR`, `NOT`, `NEG`, `CLR`, `GET`
- Memory instructions: `LD base, offset`, `ST base, offset`
- Branch instructions: `BZ`, `BNZ`, `BN`, `BNN`, `BC`, `BNC`, `BRA`, `BNV`
- Immediate and special instructions: `LDI`, `PUT`, `JR`, `HALT`, `NOP`, `SET6`, `SET7`, `SETP`, `CLC`
- Labels, `.org`, `.equ`
- Pseudo-instructions:
  - `LI value`, expanded into `LDI` plus optional `SET6`/`SET7`
  - `JMP label, reg`, expanded into `LI`, `PUT`, `SETP`, `JR`
  - long conditional jumps such as `JZ`, `JNZ`, `JC`, and `JNC`, expanded as inverse short branch plus long jump

Assembler tests are in:

```text
tests/test_aria_asm.py
```

## 6.c. Program 1: Hamming Distance Min/Max

Source:

```text
software/program1.asm
software/program1.mem
software/program1.lst
```

Program 1 computes the minimum and maximum Hamming distance across all unordered pairs of 32 16-bit operands. Operands are read from `core[0:63]`, with operand `i` stored at `{core[2*i], core[2*i+1]}`.

The program uses nested loops:

- Outer loop: `j = 0..30`
- Inner loop: `k = j+1..31`
- For each pair, load both bytes of both operands
- XOR corresponding high and low bytes
- Count set bits using shift/carry popcount logic
- Update running minimum and maximum

Scratch memory starts at address 128:

| Address | Meaning |
| --- | --- |
| `128` | `j` |
| `129` | `k` |
| `130` | minimum Hamming distance |
| `131` | maximum Hamming distance |

Outputs:

| Address | Meaning |
| --- | --- |
| `64` | minimum Hamming distance |
| `65` | maximum Hamming distance |

## 6.d. Program 2: Arithmetic Distance Min/Max

Source:

```text
software/program2.asm
software/program2.mem
software/program2.lst
```

Program 2 computes the minimum and maximum absolute arithmetic distance across all unordered pairs of 32 signed 16-bit operands. The output distances are unsigned 16-bit magnitudes.

The program uses nested loops over all pairs. For each pair:

- Load signed 16-bit operands `a` and `b`
- Determine signed ordering using sign-bit checks and unsigned high/low comparisons
- Compute `larger - smaller` as a 16-bit unsigned magnitude
- Compare the 16-bit result against the running minimum and maximum, high byte first
- Store final min/max in big-endian byte order

Scratch memory starts at address 128:

| Address | Meaning |
| --- | --- |
| `128` | `j` |
| `129` | `k` |
| `130:131` | minimum distance |
| `132:133` | maximum distance |
| `134:135` | current distance |

Outputs:

| Address | Meaning |
| --- | --- |
| `66:67` | minimum arithmetic distance |
| `68:69` | maximum arithmetic distance |

## 6.e. Program 3: Signed 16-bit Multiplication

Source:

```text
software/program3.asm
software/program3.mem
software/program3.lst
```

Program 3 computes 16 signed products from 32 signed 16-bit operands. For each pair, it multiplies:

```text
operand[2*i+1] * operand[2*i]
```

The program uses this strategy:

- Loop over 16 operand pairs
- Load both signed 16-bit operands
- Convert each operand to magnitude if negative
- Track the final sign by XORing operand signs
- Perform a 16-cycle shift-add multiplication
- Conditionally two's-complement the 32-bit product if the signs differ
- Store the 32-bit product in big-endian order

Scratch memory:

| Address | Meaning |
| --- | --- |
| `128` | product index |
| `129` | product sign |
| `130` | output address |
| `131` | input address |
| `132` | multiply loop counter |
| `136:139` | 32-bit product |
| `140:143` | 32-bit shifted multiplicand |
| `144:145` | 16-bit shifted multiplier |

Outputs:

| Address | Meaning |
| --- | --- |
| `64:127` | 16 big-endian 32-bit products |

## 6.f. Manual Verification

Run all assembly generation:

```sh
make asm
```

Run individual exported program benches:

```sh
make sim_prog1
make sim_prog2
make sim_prog3
```

Run all checks:

```sh
python3 -m unittest tests/test_aria_asm.py
make sim_all
```

Expected exported bench summaries:

```text
Program 1:
Minimum correct          10/         10
Maximum correct          10/         10

Program 2:
Minimum correct          10/         10
Maximum correct          10/         10

Program 3:
Tests passed          10/         10
```

The `$readmemb` warnings about not enough words are expected because the exported input files initialize only the operand region rather than all 256 data-memory entries.

# Changelog

- Milestone 3
  - Software
    - Added real ARIA assembly implementations for Programs 1, 2, and 3.
    - Added generated 1024-line machine-code ROM images `program1.mem`, `program2.mem`, and `program3.mem`.
    - Added generated listing files `program1.lst`, `program2.lst`, and `program3.lst`.
    - Added an ARIA assembler supporting labels, `.org`, `.equ`, real ISA instructions, and long-jump pseudo-instructions.
    - Added assembler unit tests for instruction encodings, pseudo-instruction expansion, labels, directives, ROM length, and expected failures.
  - Hardware
    - Replaced the previous program-specific algorithmic `DUT.sv` implementation with a real single-cycle ARIA CPU fetch/decode/execute path.
    - Connected the CPU to the existing program counter, instruction memory, decoder, branch unit, register file, ALU, and data memory.
    - Preserved the data memory instance name `dm`, so exported benches can still access `D1.dm.core`.
    - Implemented explicit CPU handling for `CMP`, `LDI`, `PUT`, `JR`, `HALT`, `NOP`, `SET6`, `SET7`, `SETP`, and `CLC`.
    - Fixed memory direction decoding so `LD` uses `01_1_bbb_qqq` and `ST` uses `01_0_bbb_qqq`.
    - Added `NO_IMEM_LOAD` support for testbenches that inject a hand-written ROM directly.
  - Verification
    - Added a CPU smoke test covering `LDI`, `PUT`, `LD`, `ST`, `CMP`, conditional branches, `CLC`, `SETP`, `JR`, and `HALT`.
    - Added Makefile targets to assemble programs and run component, CPU smoke, and exported program benches.
    - Verified Program 1 against exported testbenches: minimum 10/10 and maximum 10/10.
    - Verified Program 2 against exported testbenches: minimum 10/10 and maximum 10/10.
    - Verified Program 3 against exported testbenches: tests passed 10/10.
- Milestone 2
  - Defined the ARIA 9-bit accumulator-register ISA, including instruction formats, register model, branch conditions, flags, memory operations, immediate operations, and special operations.
- Milestone 1
  - Initial architecture proposal and early component planning.
