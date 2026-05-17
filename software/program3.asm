; Program 3: 16 signed 16x16->32 products.
; R7=128 loop/sign: [0]=idx, [1]=sign, [2]=outaddr, [3]=inaddr, [4]=count.
; R6=136 product/multiplicand: [0:3]=product, [4:7]=multiplicand.
; R5=144 multiplier: [0:1]=multiplier.

start:
  ; Initialize scratch bases and constant 1.
  LI 128
  PUT R7
  LI 136
  PUT R6
  LI 144
  PUT R5
  LI 1
  PUT R3
  LI 0
  ST R7, 0

pair_loop:
  ; Process 16 operand pairs; idx selects operands 2*idx and 2*idx+1.
  LD R7, 0
  PUT R1
  LDI 16
  CMP R1
  JZ finish, R4

  ; input address = 4*idx because each pair is four bytes.
  ; output address = 64 + 4*idx for the 32-bit product.
  GET R1
  ADD R1
  ADD R1
  ADD R1
  PUT R2
  ST R7, 3
  LI 64
  ADD R2
  ST R7, 2

  ; Clear sign and the low 16 bits of the 32-bit product/multiplicand area.
  LI 0
  ST R7, 1
  ST R6, 0
  ST R6, 1
  ST R6, 2
  ST R6, 3
  ST R6, 4
  ST R6, 5

  ; Load operand A into R1:R2 from core[input+0:input+1].
  LD R7, 3
  PUT R4
  LD R4, 0
  PUT R1
  LD R4, 1
  PUT R2

  ; If A is negative, set sign and store magnitude -A in multiplicand[6:7].
  ; Otherwise copy A directly into multiplicand[6:7].
  GET R1
  LSL
  JNC a_positive, R4
a_negative:
  LI 1
  ST R7, 1
  LDI 0
  SUB R2
  ST R6, 7
  LDI 0
  SUBB R1
  ST R6, 6
  JMP load_b, R4
a_positive:
  GET R1
  ST R6, 6
  GET R2
  ST R6, 7

load_b:
  ; Load operand B into R1:R2 from core[input+2:input+3].
  LD R7, 3
  PUT R4
  LD R4, 2
  PUT R1
  LD R4, 3
  PUT R2

  ; If B is negative, toggle sign and store magnitude -B in multiplier[0:1].
  ; Otherwise copy B directly into multiplier[0:1].
  GET R1
  LSL
  JNC b_positive, R4
b_negative:
  LD R7, 1
  XOR R3
  ST R7, 1
  LDI 0
  SUB R2
  ST R5, 1
  LDI 0
  SUBB R1
  ST R5, 0
  JMP multiply_init, R4
b_positive:
  GET R1
  ST R5, 0
  GET R2
  ST R5, 1

multiply_init:
  ; Run a 16-cycle shift-add multiply.
  LI 16
  ST R7, 4

mult_loop:
  ; If multiplier bit 0 is set, add shifted multiplicand into product.
  LD R5, 1
  LSR
  JNC skip_add, R4
  LD R6, 7
  PUT R1
  LD R6, 3
  ADD R1
  ST R6, 3
  LD R6, 6
  PUT R1
  LD R6, 2
  ADDC R1
  ST R6, 2
  LD R6, 5
  PUT R1
  LD R6, 1
  ADDC R1
  ST R6, 1
  LD R6, 4
  PUT R1
  LD R6, 0
  ADDC R1
  ST R6, 0
skip_add:
  ; Shift the 32-bit multiplicand left by one bytewise through carry.
  LD R6, 7
  LSL
  ST R6, 7
  LD R6, 6
  ROL
  ST R6, 6
  LD R6, 5
  ROL
  ST R6, 5
  LD R6, 4
  ROL
  ST R6, 4

  ; Shift the 16-bit multiplier right by one bytewise through carry.
  LD R5, 0
  LSR
  ST R5, 0
  LD R5, 1
  ROR
  ST R5, 1

  LD R7, 4
  SUB R3
  ST R7, 4
  JNZ mult_loop, R4

  ; If exactly one operand was negative, negate the 32-bit product.
  LD R7, 1
  CMP R3
  JNZ store_product, R4
neg_product:
  LD R6, 3
  PUT R1
  LDI 0
  SUB R1
  ST R6, 3
  LD R6, 2
  PUT R1
  LDI 0
  SUBB R1
  ST R6, 2
  LD R6, 1
  PUT R1
  LDI 0
  SUBB R1
  ST R6, 1
  LD R6, 0
  PUT R1
  LDI 0
  SUBB R1
  ST R6, 0

store_product:
  ; Store the 32-bit product in big-endian order at core[64 + 4*idx].
  LD R7, 2
  PUT R4
  LD R6, 0
  ST R4, 0
  LD R6, 1
  ST R4, 1
  LD R6, 2
  ST R4, 2
  LD R6, 3
  ST R4, 3

  ; idx++ and continue with the next operand pair.
  LD R7, 0
  ADD R3
  ST R7, 0
  JMP pair_loop, R4

finish:
  HALT
