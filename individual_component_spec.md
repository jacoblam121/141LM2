# 5. Individual Component Specification

This section describes the individual hardware blocks used by the ARIA processor. ARIA is a 9-bit instruction-width, accumulator-register, Harvard-style processor. Instruction memory is separate from data memory, R0 is the accumulator, R1-R7 are general-purpose registers, and the architectural status flags are Z, N, and C.

## 5.a. Top Level

**Module file name:** `rtl/DUT.sv`  
**Module name:** `DUT`

### Functionality Description

The top-level module connects the processor-visible blocks and exposes the testbench interface:

```systemverilog
module DUT #(
  parameter int PROGRAM_ID = 1
)(
  input  logic clk,
  input  logic start,
  output logic done
);
```

`start` is the reset/restart input. When `start` is high, the processor architectural state is reset and `done` is cleared. Execution begins after `start` goes low. `done` is a registered completion signal that is asserted only after the selected program has finished writing its required output bytes.

The top level instantiates the data memory as `dm`, so the exported testbenches can preload input data and inspect output data through `D1.dm.core`. It also instantiates the program counter and instruction memory blocks used by the ARIA fetch path. Program selection is controlled by the `PROGRAM_ID` parameter or by compile-time defines `PROG1`, `PROG2`, and `PROG3`.

### Schematic

Insert top-level schematic here. The schematic should show:

- `clk`, `start`, and `done`
- Program counter / fetch path
- Instruction memory
- Control/decode path
- Register file
- ALU and flag path
- Data memory instance `dm`
- Writeback and memory-address muxing

## 5.b. Program Counter

**Module file name:** `rtl/aria_pc.sv`  
**Module name:** `aria_pc`  
**Module testbench file name:** `tb/pc_tb.sv`

### Functionality Description

The program counter module stores the current 10-bit instruction address. The 10-bit width supports up to 1,024 instruction-memory entries. On `start`, the PC resets to zero. During normal execution, the PC increments by one each cycle.

The PC also supports two control-flow mechanisms:

- Short signed branches: `PC <- PC + 1 + sign_extend(offset4)`
- Register jumps: `PC <- {PC_PAGE, jr_addr}`

The branch offset is a 4-bit signed displacement, giving a branch range of -8 to +7 instructions from `PC + 1`. The register jump path combines the 2-bit `PC_PAGE` value with an 8-bit register value so a program can jump anywhere in the 1,024-entry instruction memory.

When `halt` is asserted, the PC holds its current value.

### Testbench Description

`tb/pc_tb.sv` verifies:

- Reset to address zero while `start` is asserted
- Sequential PC increment
- Positive signed branch offset
- Negative signed branch offset
- Branch-not-taken behavior
- Register jump using `PC_PAGE`
- Halt hold behavior
- 10-bit wraparound from `10'h3ff` to `10'h000`

### Schematic

Insert program counter schematic here. The schematic should include the PC register, incrementer, signed branch adder, JR target concatenation, next-PC mux, and reset/halt controls.

### Timing Diagram

Insert timing diagram screenshot here. The timing diagram should demonstrate reset, increment, branch, JR, halt hold, and wraparound.

## 5.c. Instruction Memory

**Module file name:** `rtl/aria_imem.sv`  
**Module name:** `aria_imem`

### Functionality Description

Instruction memory is a Harvard instruction ROM addressed by the 10-bit program counter. Each instruction is 9 bits wide. The architectural limit is 1,024 entries, matching the 10-bit PC.

The instruction format is selected by the high instruction bits:

| Prefix | Format | Meaning |
| --- | --- | --- |
| `00` | Format A | ALU operation |
| `01` | Format B | Memory load/store |
| `10` | Format C | Branch |
| `110` | Format D | 6-bit immediate load |
| `111` | Format E | Special operation |

Unused instruction-memory entries should decode as a safe instruction such as `HALT` or `NOP` so execution never consumes unknown values.

### Schematic

Insert instruction memory schematic here. The schematic should show a 10-bit address input, 9-bit instruction output, and the selected program image.

## 5.d. Control Decoder

**Module file name:** `rtl/aria_decoder.sv`  
**Module name:** `aria_decoder`

### Functionality Description

The control decoder interprets the 9-bit instruction and produces format-specific control fields. Decode is hierarchical: first inspect `inst[8:7]`, then distinguish immediate and special instructions when the prefix is `11`.

The decoder exposes:

- Instruction format
- ALU opcode `oooo`
- Register selector `rrr`
- Branch condition `ccc`
- Immediate field `iiiiii`
- Special opcode `sss`
- Memory direction bit `m`

The decoder supports the ARIA format map:

| Format | Encoding | Fields |
| --- | --- | --- |
| ALU | `00 oooo rrr` | ALU operation and source register |
| Memory | `01 m bbb qqq` | load/store, base register, unsigned offset |
| Branch | `10 ccc dddd` | branch condition and signed offset |
| Immediate | `110 iiiiii` | zero-extended 6-bit immediate |
| Special | `111 sss rrr` | special operation and register field |

### Schematic

Insert control decoder schematic here. The schematic should show format decode, opcode decode, control-signal generation, and branch-condition decode.

## 5.e. Register File

**Module file name:** `rtl/aria_reg_file.sv`  
**Module name:** `aria_reg_file`

### Functionality Description

The register file contains eight 8-bit registers, `R0` through `R7`. `R0` is the accumulator and is the implicit destination for Format A ALU instructions. `R1` through `R7` are general-purpose registers used for loop counters, pointers, temporary byte storage, min/max values, output pointers, and scratch values.

The register file supports:

- Two asynchronous read ports
- One synchronous write port
- Reset of all registers when `start` is asserted
- One register write per cycle

This satisfies the project constraint of no more than two register reads and one register write per instruction.

### Register Roles

| Register | Role |
| --- | --- |
| `R0` | Accumulator |
| `R1` | General register, often loop counter |
| `R2` | General register, often inner loop counter |
| `R3` | General register, often input pointer |
| `R4` | General register, temporary byte/value |
| `R5` | General register, temporary byte/value |
| `R6` | General register, often min/max or output pointer |
| `R7` | General register, often output pointer/scratch |

### Schematic

Insert register file schematic here. The schematic should show the eight registers, two read address ports, one write address port, write enable, write data, and read data outputs.

## 5.f. ALU (Arithmetic Logic Unit)

**Module file name:** `rtl/aria_alu.sv`  
**Module name:** `aria_alu`  
**Module testbench file name:** `tb/alu_tb.sv`

### Functionality Description

The ALU is combinational logic operating on the accumulator value `R0`, one source register value `Rs`, and the incoming carry flag. It produces an 8-bit result and three flags:

| Flag | Meaning |
| --- | --- |
| `Z` | Result is zero |
| `N` | Result bit 7 is set |
| `C` | Carry for addition, borrow for subtraction, shifted-out bit for shifts/rotates |

Most ALU operations write the result back to `R0`. `CMP` is the exception: it computes flags for `R0 - Rs` but does not overwrite `R0`.

### Testbench Description

`tb/alu_tb.sv` applies representative operands to every ALU opcode and checks the result and flags. The tests include carry-in, borrow, zero result, negative result, shifts, rotates through carry, compare behavior, and register pass-through.

### ALU Operations

| Opcode | Mnemonic | Operation | Notes |
| --- | --- | --- | --- |
| `0000` | `ADD` | `R0 + Rs` | Updates Z, N, C |
| `0001` | `ADDC` | `R0 + Rs + C` | Multi-byte addition |
| `0010` | `SUB` | `R0 - Rs` | C means borrow |
| `0011` | `SUBB` | `R0 - Rs - C` | Multi-byte subtraction |
| `0100` | `AND` | `R0 & Rs` | Bit masks/tests |
| `0101` | `OR` | `R0 | Rs` | Bit combining |
| `0110` | `XOR` | `R0 ^ Rs` | Hamming distance support |
| `0111` | `CMP` | flags for `R0 - Rs` | No R0 writeback |
| `1000` | `LSL` | `R0 << 1` | Old bit 7 goes to C |
| `1001` | `LSR` | `R0 >> 1` | Old bit 0 goes to C |
| `1010` | `ROL` | rotate left through C | Old C enters bit 0 |
| `1011` | `ROR` | rotate right through C | Old C enters bit 7 |
| `1100` | `NOT` | `~R0` | Bitwise invert |
| `1101` | `NEG` | `-R0` | Two's-complement negate |
| `1110` | `CLR` | `0` | Clear accumulator |
| `1111` | `GET` | `Rs` | Copy register into accumulator |

### Schematic

Insert ALU schematic here. The schematic should show arithmetic, logic, shift/rotate, and pass-through result paths feeding a result mux, plus flag-generation logic.

### Timing Diagram

Insert ALU timing diagram screenshot here. The timing diagram should demonstrate all 16 ALU operations and the resulting Z/N/C flags.

## 5.g. Data Memory

**Module file name:** `rtl/dat_mem.sv`  
**Module name:** `dat_mem`

### Functionality Description

Data memory is a 256-byte RAM with one address port. It has asynchronous read and synchronous write behavior:

- `core[0:63]` holds the 32 input 16-bit operands loaded by the testbench.
- Program 1 writes min/max Hamming distance to `core[64]` and `core[65]`.
- Program 2 writes min/max arithmetic distance to `core[66:69]`.
- Program 3 writes sixteen 32-bit products to `core[64:127]`.
- `core[128:255]` is available as scratch space.

The exported testbenches access memory using the required hierarchical path `D1.dm.core`, so the array is declared as `logic [7:0] core[256]` inside the `dat_mem` module.

### Schematic

Insert data memory schematic here. The schematic should show the 8-bit address port, 8-bit data input, 8-bit data output, write enable, clock, and 256-byte storage array.

## 5.h. Lookup Tables

**Module file name:** N/A

### Functionality Description

No large lookup table is required for ARIA. The control path uses direct field decode from the 9-bit instruction, and the ALU implements operations directly with combinational arithmetic, logic, and shift/rotate hardware.

Small decode tables may be represented as `case` statements for:

- ALU opcode selection
- Branch condition selection
- Special instruction selection

Each decode table is well below the 32-entry limit.

### Schematic

No lookup-table schematic is required unless the final implementation introduces a separate lookup-table module.

## 5.i. Muxes

**Module file name:** integrated into datapath modules

### Functionality Description

The processor uses muxes in several datapath locations:

- Next-PC mux selects sequential PC, branch target, JR target, or hold.
- ALU result mux selects arithmetic, logic, shift/rotate, clear, negate, or register pass-through result.
- Writeback mux selects ALU result, load data, immediate data, or special-operation result for writes to `R0`.
- Data-memory address mux selects the base-register-plus-offset address for loads and stores.

### Schematic

Insert mux/datapath schematic here if shown separately from the top-level schematic.

## 5.j. Branch Condition Logic

**Module file name:** `rtl/aria_branch.sv`  
**Module name:** `aria_branch`

### Functionality Description

The branch condition logic evaluates the 3-bit branch condition field against the architectural flags Z, N, and C.

| Condition Field | Mnemonic | Taken When |
| --- | --- | --- |
| `000` | `BZ` | `Z = 1` |
| `001` | `BNZ` | `Z = 0` |
| `010` | `BN` | `N = 1` |
| `011` | `BNN` | `N = 0` |
| `100` | `BC` | `C = 1` |
| `101` | `BNC` | `C = 0` |
| `110` | `BRA` | Always |
| `111` | `BNV` | Never |

The branch unit feeds the program-counter branch-taken input.

### Schematic

Insert branch-condition logic schematic here. The schematic should show Z/N/C inputs, condition decode, and the branch-taken output.

## 5.k. PC_PAGE Register

**Module file name:** integrated into `rtl/DUT.sv`

### Functionality Description

`PC_PAGE` is a 2-bit architectural register written by the `SETP` special instruction. Register jumps form a 10-bit target by concatenating `PC_PAGE` with an 8-bit register value:

```text
PC <- {PC_PAGE, R[rrr]}
```

This allows ARIA to reach all 1,024 instruction-memory entries even though each instruction is only 9 bits wide.

### Schematic

Insert PC_PAGE schematic here or include it as part of the PC/fetch schematic.
