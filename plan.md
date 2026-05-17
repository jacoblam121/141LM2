  # Milestone 3 ARIA Assembler And Software Plan

  ## Summary

  Build Milestone 3 as the full software path: a Python assembler, assembly programs, generated machine-code ROM files, and RTL integration so the exported benches execute assembled ARIA
  code. Treat Milestone 2.pdf as the ISA source of truth. Current rtl/DUT.sv is still a dummy wrapper, so it must be replaced with the real fetch/decode/execute datapath for assembler output
  to matter.

  ## Key Changes

  - Align RTL with the PDF ISA:
      - Branch encoding: BZ=000, BNZ=001, BN=010, BNN=011, BC=100, BNC=101, BRA=110, BNV=111.
      - Memory encoding: LD = 01_1_bbb_qqq, ST = 01_0_bbb_qqq; loads write R0, stores write data memory.
      - CMP updates flags but suppresses R0 writeback.
      - LDI, SET6, SET7, PUT, JR, HALT, NOP, SETP, and CLC get explicit writeback/control handling.
  - Replace rtl/DUT.sv dummy logic with a single-cycle ARIA CPU using the existing PC, imem, decoder, branch, reg file, ALU, and data memory modules.
  - Update rtl/aria_imem.sv to initialize a 1024x9 ROM from generated .mem files selected by -DPROG1, -DPROG2, or -DPROG3.

  ## Assembler

  - Add software/aria_asm.py with no third-party dependencies.
    python3 software/aria_asm.py software/program1.asm -o software/program1.mem --listing software/program1.lst

  - Support labels, comments, .org, .equ, decimal/hex/binary literals, R0-R7, and case-insensitive mnemonics.
  - Emit 1024-line, 9-bit binary $readmemb ROM files plus human-readable listings.
  - Validate register numbers, immediate ranges, memory offsets 0..7, ROM addresses 0..1023, and short branch offsets -8..+7.
  - Add fixed-size helpers:
      - LI value: always emits LDI low6, then SET6/NOP, then SET7/NOP.
      - JMP label, Rn: emits fixed 6-instruction absolute jump using LI, PUT, SETP, JR.
      - JZ/JNZ/JN/JNN/JC/JNC label, Rn: emits inverse short branch over JMP.

  ## Programs

  - Add software/program1.asm, program2.asm, and program3.asm, with generated .mem and .lst files.
  - Program 1 computes all pairwise 16-bit Hamming distances and stores min/max at core[64] and core[65].
  - Program 2 computes all pairwise signed 16-bit arithmetic distances and stores min/max big-endian at core[66:69].
  - Program 3 computes sixteen signed 16x16 products and stores 32-bit big-endian results at core[64:127].
  - Use core[128:255] as scratch only; never modify input core[0:63] or unrelated output regions.

  ## Test Plan

  - Add assembler golden tests for every real instruction, branch-label resolution, pseudo-instruction expansion, and expected failures.
  - Run:

    make asm
    make sim_alu_tb
    make sim_pc_tb
    make sim_prog1
    make sim_prog2
    make sim_prog3
    make sim_all

  - Acceptance:
      - ALU and PC benches still pass.
      - Program 1 reports Minimum correct 10/10 and Maximum correct 10/10.
      - Program 2 reports Minimum correct 10/10 and Maximum correct 10/10.
      - Program 3 reports Tests passed 10/10.

  ## Assumptions

  - Use the PDF encoding over the current aria_branch.sv mismatch.
  - Keep exported test benches unchanged.
  - Use rtl_alt/DUT.sv only as an algorithm reference, not as the final CPU implementation.
- If any assembled program exceeds 1024 instructions, optimize the assembly before changing ISA or memory limits.