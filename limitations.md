Architecture Limitations and Requirements

1. Your core should have separate instruction memory and data memory.
2. You should assume single-ported data memory (a maximum of one read or one write per instruction, not both — Your data memory will have only one address pointer input port, for both input and output). You can write and read in place.
3. Your instruction memory should not exceed 2^10 entries; it must not exceed 2^12 entries. If you need the larger number of instruction entries, your writeup must explain how these extra entries improve some other performance element.
4. Your data memory must not exceed 2^8 entries.
5. You should also assume a register file (or whatever internal storage you support) that can write to only one register per instruction.
a. The sole exception to this rule is that you may have a multibit ALU condition/flag register (e.g., carry out, or shift out, sign result, zero bit, etc., like ARM's Z, N, C, and V status bits) that can be written at the same time as an 8-bit data register, if you want.
b. You may read up to two data registers per cycle.
c. Your register file will have no more than two data output ports and one data input port.
d. You may use separate pointers for reads and writes, if you wish.
e. Please restrict register file size to no more than 16 registers.
6. Manual loop unrolling of your code is not allowed – use at least some branch or jump instructions.
7. Your ALU instructions will be a subset of those in ARMsim, or of comparable complexity.
8. You may use lookup tables / decoders, but these are limited to 32 elements each (i.e., pointer width up to 5 bits).
a. You may not, for example, build a big 512-element, 32-bit LUT to map your 9-bit machine codes into ARM- or MIPS-like wider microcode.