# Implementation Plan Feedback

## What's Correct

- **DUT interface** (`clk`, `start`, `done`) matches all 9 testbench files. Benches instantiate `DUT D1(.clk, .start, .done)` with no parameters.
- **`dat_mem` structure** — instance name `dm`, array `logic [7:0] core[256]`, async read / sync write — enables hierarchical access via `D1.dm.core` in all benches.
- **Start/done protocol** — `start=1` holds reset, execution begins when `start=0`, `done` latches on HALT, `#200ns` guard delays before and after `wait(done)`. Matches all benches.
- **All memory regions** match what benches check: Program 1 output at core[64:65], Program 2 at core[66:69], Program 3 at core[64:127]. Input at core[0:63].
- **Scratch space at 128..255** is safe — avoids input (0..63) and all three output regions.
- **Byte ordering is big-endian** — verified against concat patterns: `{core[66], core[67]}` places core[66] as MSB, `{core[67+4k], core[66+4k], core[65+4k], core[64+4k]}` places core[64+4k] as MSB.
- **All `limitations.md` constraints** respected: instruction memory ≤1024 (2^10), data memory 256 (2^8), register file ≤16 regs with ≤2 read ports and ≤1 write port, no manual loop unrolling.
- **Leaf module decomposition** (PC, instruction memory, decoder, register file, ALU, flag register, data memory, muxes, DUT wrapper) maps 1:1 to the required report sections in document.pdf.
- **ISA is conceptually correct** — already verified.

---

## Issues

### 1. PROGRAM_ID parameter approach breaks testbench compatibility

All 4 testbench files instantiate DUT as:

```systemverilog
DUT D1(.clk(clk), .start(start), .done(done));
```

No `#()` parameter override is present. The plan proposes `DUT #(parameter int PROGRAM_ID = 1)` and applying `-P DUT.PROGRAM_ID=1` on the simulator command line. This is simulator-specific and fragile:

- Icarus Verilog: `-P DUT.PROGRAM_ID=1` works
- ModelSim/Questa: requires `-gPROGRAM_ID=1`
- Verilator: requires `-GPROGRAM_ID=1`
- VCS/Xcelium: entirely different syntax

**Resolution**: Either (a) use `` `ifdef PROG1`` / `` `ifdef PROG2`` / `` `ifdef PROG3`` with `+define+` on the command line (universally supported), or (b) create three wrapper modules (e.g., `DUT_prog1`) that hardcode PROGRAM_ID internally and have the 3-port interface, so benches can instantiate the wrapper without parameter overrides. Option (a) is simpler. The plan must name the target simulator and provide exact invocation commands.

### 2. No build infrastructure exists

There are zero Makefiles, scripts, or `.do` files in the repo. The plan mentions creating one but provides no structure. The build system needs:

- Explicit targets for each program's simulation (program1 bench, program2 bench, program3_new bench)
- Working directory set to `test_benches_export/test_files/` (or symlink/copy) so `$readmemb("test0.txt", ...)` resolves
- Component testbench targets for ALU and PC
- The exact simulator invocation with `ifdef` or parameter flags

### 3. PC_PAGE register not mentioned in the plan

The ISA (document.pdf) defines a 2-bit `PC_PAGE` register set by the `SETP` instruction and concatenated with a register value by `JR` to form a 10-bit jump target: `PC ← {PC_PAGE, R[rr]}`. The plan mentions "branch/jump address logic" but never names PC_PAGE or describes its implementation. This is a distinct 2-bit register that feeds a mux into the 10-bit PC — it needs to appear in the leaf module list and data path.

### 4. CMP instruction requires a register-file write-enable exception

`CMP` computes `R0 - Rs` and updates Z/N/C flags but does **not** write the result back to R0 (unlike all other Format A ALU ops). The plan's "R0 is accumulator — all ALU results write here" rule needs a single exception: when the ALU opcode is `CMP` (0111), the register file write-enable signal must be suppressed. The plan doesn't address this. Implementation options: (a) a separate `wen` control signal derived from the opcode in the decoder, or (b) an ALU output that signals "no writeback."

### 5. Multi-level format decode needs explicit description

Instruction formats use:
- 2-bit prefix for A/B/C: `00` (ALU), `01` (memory), `10` (branch)
- 3-bit prefix for D/E: `110` (immediate), `111` (special)

The decoder must check `inst[8:7]` first, then conditionally check `inst[6]` when `inst[8:7] == 2'b11`. The plan doesn't describe this decode structure. Since the plan mentions a ≤32-element LUT limit, you need to confirm the format-select + opcode-decode cascade fits (it should: 16 ALU ops × 4-bit, 8 branch conds × 3-bit, 8 special ops × 3-bit, plus 2 memory directions — but this needs to be counted and verified).

### 6. ALU opcode list is not enumerated

The plan says "ALU, flag register behavior" but doesn't list the 16 required operations: ADD, ADDC, SUB, SUBB, AND, OR, XOR, CMP, LSL, LSR, ROL, ROR, NOT, NEG, CLR, GET. The ALU component testbench must cover all 16. Additionally:

- **Shift/rotate-through-carry** (LSL, LSR, ROL, ROR) treat C as a 9th bit: the shifted-out bit becomes the new C, and for rotates the old C becomes the new bit on the opposite end.
- **ADDC/SUBB** use the incoming C flag as carry-in for multi-byte arithmetic.
- **GET** copies R[rr] to R0 (a pass-through mux operation, not arithmetic).
- **NEG** computes two's complement (`R0 ← -R0` = `~R0 + 1`).

### 7. SET6/SET7 are non-standard data path operations

`SET6` (`R0 ← R0 | 0x40`) and `SET7` (`R0 ← R0 | 0x80`) are Special-format instructions (111_100_000 and 111_101_000) that modify R0 but are not Format A ALU ops. The data path needs a way to perform bitwise-OR with a constant on R0. Options: (a) route these through the ALU as a dedicated OR-with-immediate operation, (b) add a separate SET6/SET7 path to the register file write port, or (c) implement SET6/SET7 as ALU ops that take 0x40/0x80 as the second operand. The plan should specify which approach.

### 8. LDI is 6-bit zero-extended immediate

`LDI` ("110 iiiiii") loads a 6-bit unsigned value (0–63) into R0. Larger constants require chaining `SET6`/`SET7`. The plan should specify how the 6-bit immediate field is routed to the register file write port (likely bypassing the ALU entirely, or going through the ALU's second operand mux as a zero-extended value). This is a data-path routing decision that affects the mux design.

### 9. Branch range is tight: -8 to +7 instructions

The 4-bit signed branch offset severely limits inner-loop body size. The plan states "Use loops/branches/JR as required" and the PDF provides partial assembly showing the inner loops use short branches. The plan should confirm that each program's inner-loop body fits within the branch range without requiring JR for short-distance jumps. If a loop body exceeds 8 instructions, the inverse-branch + JR idiom is needed, which the PDF documents.

### 10. test2.txt has anomalous format

`test_benches_export/test_files/test2.txt` contains 79 lines — 64 data lines with 15 blank lines interspersed. `$readmemb` should skip blank lines, but behavior may vary by simulator. Worth noting in the build script or test plan.

### 11. Component testbenches underspecified

The PDF (document.pdf §5.b, §5.f) explicitly requires testbenches for the Program Counter and ALU. The plan says "Add focused component testbenches for ALU and program counter" but provides zero detail: no test cases, no expected behavior, no pass/fail criteria. Minimum coverage should include:

**ALU testbench**: Feed all 16 opcodes with representative operands (including edge cases like carry-in=1, negative values, zero) and verify result + flags.
**PC testbench**: Verify reset-to-zero on start, sequential increment, branch taken/not-taken for each condition, JR with PC_PAGE, and wrap-around behavior.

### 12. Instruction ROM image format unspecified

How are the three program ROM images provided? Possibilities:
- Separate `.mem` or `.txt` files loaded via `$readmemb`/$`readmemh` at compile time
- SystemVerilog `case` statements inside the instruction memory module, selected by `ifdef`
- A `generate` block that selects a pre-initialized array

The plan must specify this so the build script knows how to select the right ROM per program. Since instruction memory is 1024×9 and the programs likely use far fewer entries, the ROM module should handle uninitialized entries gracefully.

### 13. Working directory for simulation not specified

Benches use bare filenames: `$readmemb("test0.txt", D1.dm.core)`. These resolve relative to the simulator's working directory. The plan says "set the working directory so test0.txt through test9.txt resolve" but doesn't specify whether to `cd` into `test_benches_export/test_files/`, create symlinks, or use simulator `-f` flags. This matters for the Makefile/script design.

### 14. Cross-hierarchy data memory access timing

Benches preload `D1.dm.core` via hierarchical reference at time zero before `start` falls. The DUT's data memory is synchronous (writes on `posedge clk`). The plan should note that the DUT must not write to addresses 0–63 (input region) during execution, since the benches rely on those values remaining intact. Similarly, scratch space at 128–255 must be used carefully to avoid corrupting the output region 64–127.

### 15. HALT instruction and done latching

The dummyDUT uses combinational done (`always_comb done = prog_ct == 10`), but the plan correctly says "done latches high on HALT." The real DUT must latch `done` with a flip-flop that sets on HALT and clears on `start`. This is a small but critical difference from the dummyDUT — if done is combinational, a glitch might trigger `wait(done)` prematurely.

---

## Recommendations

1. **Use `` `ifdef PROG1`` / `` `ifdef PROG2`` / `` `ifdef PROG3``** for program selection instead of parameter overrides. This works universally across all simulators.

2. **Add `PC_PAGE` to the leaf module list** and describe its integration with JR in the data path.

3. **Add a CMP writeback suppression signal** in the decoder or register-file write-enable logic.

4. **Describe the two-level format decode** (`inst[8:7]` → format, `inst[8:6]` for 11x prefix) and count LUT entries.

5. **Enumerate the full ALU opcode table** (16 ops), full branch condition table (8), and full special-op table (8) with their encodings.

6. **Design the SET6/SET7/LDI data path** — specify how non-ALU writes to R0 are routed.

7. **Verify inner-loop instruction counts** for all three programs don't exceed the 8-instruction branch range.

8. **Specify ROM image format and loading mechanism** — `$readmemb` from separate files vs. embedded `case` statements.

9. **Provide a Makefile** with targets: `sim_prog1`, `sim_prog2`, `sim_prog3`, `sim_alu_tb`, `sim_pc_tb`, and a `sim_all` target. Include the working-directory handling.

10. **Name the target simulator** and provide the exact compile/run command lines.

11. **Detail the ALU and PC component testbenches** with specific test cases.

12. **Note the test2.txt anomaly** (79 lines) and confirm it works with the chosen simulator.
