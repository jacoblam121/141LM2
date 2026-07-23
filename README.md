# ARIA CPU

ARIA (Accumulator-Register ISA Architecture) is a small processor designed and
implemented as a complete hardware/software system. The project starts with a
custom 9-bit instruction set, realizes that ISA as a single-cycle SystemVerilog
CPU, and runs nontrivial assembly programs on the resulting machine. A matching
Python assembler and several layers of simulation tests connect the software
and hardware sides.

The processor was developed for the CSE 141L term project. Its purpose is not to
compete with a general-purpose CPU, but to demonstrate how workload
requirements, a tight instruction encoding, datapath organization, and assembly
techniques influence one another.

## The Central Design Idea

ARIA's defining constraint is its 9-bit instruction width. A conventional
three-register instruction cannot fit: naming three of eight registers already
requires all nine bits, leaving no room for an opcode. Even two explicit
register operands would leave only three opcode bits and therefore too few
operations for the target programs.

ARIA resolves this encoding problem by making `R0` the accumulator. An ALU
instruction names only one source register, performs an operation using `R0`
and that register, and writes the result back to `R0`:

```text
R0 <- R0 operation Rs
```

This implicit destination frees four instruction bits for the ALU opcode, so
the compact format can represent 16 arithmetic, logical, comparison, and shift
operations. `R1` through `R7` remain general-purpose registers for operands,
pointers, loop counters, and intermediate values. `GET` moves a saved value
into the accumulator, while `PUT` moves the accumulator into another register.

Conceptually, `R0` is the processor's workbench, `R1`–`R7` are nearby shelves,
and data memory is longer-term storage. This makes ARIA a hybrid
accumulator/load-store machine: computation happens through the accumulator,
but memory is accessed only by explicit load and store instructions.

## Architectural Overview

ARIA uses an 8-bit datapath and a Harvard organization, so instructions and
data live in separate memories:

| Feature | Description |
| --- | --- |
| Instruction width | 9 bits |
| Data width | 8 bits |
| Instruction memory | 1,024 words, addressed by a 10-bit program counter |
| Data memory | 256 bytes, single port |
| Registers | Eight 8-bit registers; `R0` is the accumulator |
| Status flags | Zero (`Z`), negative (`N`), and carry/borrow (`C`) |
| Control flow | Short conditional branches and register-based absolute jumps |

The high bits divide the instruction space into five formats. Each format
reuses the remaining bits for the fields relevant to that kind of operation:

| Prefix and format | Encoding | Purpose |
| --- | --- | --- |
| `00` — ALU | `00 oooo rrr` | Apply one of 16 operations to `R0` and a register |
| `01` — Memory | `01 m bbb qqq` | Load or store at `Rbase + offset` |
| `10` — Branch | `10 ccc dddd` | Test a flag condition and apply a signed PC offset |
| `110` — Immediate | `110 iiiiii` | Load a zero-extended 6-bit value into `R0` |
| `111` — Special | `111 sss rrr` | Move data, jump, halt, or update control state |

This hierarchical encoding is the main reason a useful ISA fits into nine
bits. The formats spend bits differently instead of forcing every instruction
to carry the same fields.

### Datapath and Execution

The top-level [`DUT`](rtl/DUT.sv) connects the program counter, instruction
memory, decoder, register file, ALU, flag and branch logic, and data memory:

```text
                   +---------------------+
         PC ------>| instruction memory  |------> instruction
          ^        +---------------------+              |
          |                                               v
          +--------- branch/jump logic <------------- decoder
                         ^                                |
                         |                                v
                      Z, N, C                     register selection
                                                        |
                        +-------------------------------+
                        v                               v
                 +-------------+                 +-------------+
                 |     ALU     |<--------------->| R0 ... R7   |
                 +-------------+                 +-------------+
                        |                               |
                        +-------- writeback             |
                                                        v
                                                  data memory
```

While `start` is asserted, the program counter, registers, flags, and `done`
state are reset. After `start` is released, each clock cycle:

1. The program counter selects one 9-bit instruction.
2. The decoder identifies its format and extracts its operation, register, or
   immediate fields.
3. The datapath performs an ALU operation, accesses data memory, or evaluates a
   control-flow condition.
4. The result, flags, memory write, and next program counter are committed.

Most instructions advance to the next sequential address. A taken branch
changes the PC by a signed offset, `JR` supplies an absolute target, and `HALT`
asserts `done` and stops the PC.

### Memory and Control Flow

Data memory is a single-ported 256-byte RAM. Loads and stores use
base-register-plus-offset addressing:

```text
effective address = Rbase + unsigned offset       (offset 0...7)
LD: R0 <- memory[effective address]
ST: memory[effective address] <- R0
```

The small offset is enough to step through the bytes of 16- and 32-bit values
while keeping the encoding compact. Wider arithmetic is built from 8-bit
operations: software processes one byte at a time and propagates carry or
borrow with `ADDC`, `SUBB`, and rotate-through-carry instructions.

Control flow also has a compact and an extended form. Conditional branches use
a signed 4-bit displacement, ideal for nearby decisions and tight loops. For
distant targets, a program places the lower eight address bits in a register,
sets the two-bit `PC_PAGE`, and uses `JR` to reach any of the 1,024 instruction
addresses. The assembler hides this sequence behind long-jump
pseudo-instructions when appropriate.

## Software Workloads

The ISA was chosen around three workloads rather than in isolation. Each
testbench loads 32 signed 16-bit inputs into data-memory bytes `0` through `63`,
then allows an assembly program to compute and store its results:

| Program | Algorithm | Architectural features exercised | Output |
| --- | --- | --- | --- |
| `program1` | Minimum and maximum Hamming distance over every unordered input pair | `XOR`, shifts, carry-based bit counting, nested loops | Bytes `64:65` |
| `program2` | Minimum and maximum absolute arithmetic distance over every unordered signed input pair | Sign checks, comparison, `SUB`/`SUBB`, multi-byte min/max tracking | Bytes `66:69` |
| `program3` | Sixteen signed 16-by-16-bit products | Sign conversion, shift-and-add multiplication, carry propagation, 32-bit shifts | Bytes `64:127` |

These operations explain much of the ISA. Hamming distance motivates `XOR` and
bit shifts; arithmetic distance motivates compare, sign-aware branching, and
subtract-with-borrow; multiplication motivates add-with-carry and rotates
through carry. All three programs also need register-indirect memory access and
real loop control.

The programs execute those algorithms as assembled instructions—there is no
program-specific accelerator in the CPU. Their source, generated 9-bit machine
code, and assembly listings are kept together under `software/`.

## Hardware/Software Flow

```text
ARIA assembly (.asm)
        |
        v
software/aria_asm.py
        |
        +--> 9-bit ROM image (.mem)
        +--> human-readable listing (.lst)
                    |
                    v
             instruction memory
                    |
                    v
                ARIA CPU
                    |
                    v
              data-memory results
```

The assembler supports the complete ISA, labels, `.org`, `.equ`, and
pseudo-instructions for constructing 8-bit constants and making long jumps.
Generated ROM images contain 1,024 9-bit words and are padded with `HALT`
instructions. At runtime the CPU reads that image exactly as instruction
memory; the workloads are therefore a direct hardware/software integration
test, not a separate behavioral model of the algorithms.

## Repository Layout

| Path | Contents |
| --- | --- |
| `rtl/` | Top-level CPU and synthesizable processor components |
| `software/` | Assembler, assembly programs, ROM images, and listings |
| `tb/` | Component and CPU-level SystemVerilog testbenches |
| `test_benches_export/` | End-to-end workload benches and input vectors |
| `tests/` | Python tests for the assembler and program behavior |
| `documentation/` | Architecture, component, milestone, and design notes |
| `rtl_alt/` | Alternate/reference RTL retained outside the main build |

## Getting Started

The standard simulation flow requires:

- Python 3
- GNU Make
- Perl
- Icarus Verilog (`iverilog` and `vvp`)

On Ubuntu or Debian:

```sh
sudo apt-get update
sudo apt-get install -y python3 make perl iverilog
```

Assemble all three programs and run the main RTL and end-to-end tests:

```sh
make sim_all
```

Useful individual targets are:

```sh
make asm
make sim_alu_tb
make sim_pc_tb
make sim_cpu_smoke
make sim_prog1
make sim_prog2
make sim_prog3
```

The Python verification suite additionally requires `pytest`:

```sh
python3 -m pytest
```

To assemble one program directly:

```sh
python3 software/aria_asm.py software/program1.asm \
  -o software/program1.mem \
  --listing software/program1.lst
```

## Simulation Notes

Instruction memory reads `program.mem` from the simulator's working directory.
The Makefile creates isolated build directories and stages the appropriate
program and test-vector files before invoking `vvp`. For a Quartus Prime
simulation, copy the desired generated ROM image into the project or simulation
working directory as `program.mem`.

Warnings from `$readmemb` that the input test files do not fill data-memory
locations `0:255` are expected. Each test vector initializes only the 64-byte
input region; the remaining memory is used for outputs and scratch space.

Remove generated simulation artifacts with:

```sh
make clean
```

More detailed design material is available in the
[Milestone 2 architecture report](<Milestone 2.docx (3).pdf>),
[`documentation/individual_component_spec.md`](documentation/individual_component_spec.md),
and [`documentation/milestone3.md`](documentation/milestone3.md).
