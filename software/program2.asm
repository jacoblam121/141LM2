; Program 2: min/max signed arithmetic distance across 32 16-bit operands.
; Scratch at R7=128: [0]=j, [1]=k, [2:3]=min, [4:5]=max, [6:7]=dist.

start:
  ; Initialize scratch base, constant 1, j, min=0xffff, and max=0.
  LI 128
  PUT R7
  LI 1
  PUT R5
  LI 0
  ST R7, 0
  LI 255
  ST R7, 2
  ST R7, 3
  LI 0
  ST R7, 4
  ST R7, 5

outer_loop:
  ; Stop once all unordered pairs j<k have been visited.
  LD R7, 0
  PUT R4
  LDI 31
  CMP R4
  JZ finish, R6

  ; R6 = address of operand[j] high byte = 2*j.
  GET R4
  ADD R4
  PUT R6

  ; k starts at j+1. R5 is reset to constant 1 because long jumps reuse it.
  LI 1
  PUT R5
  GET R4
  ADD R5
  ST R7, 1

inner_loop:
  ; Stop inner loop once k reaches 32.
  LD R7, 1
  PUT R4
  LDI 32
  CMP R4
  JZ next_j, R5

  ; R5 = address of operand[k] high byte = 2*k.
  ; Save this pointer in scratch[6] because R5 is later reused for jumps.
  GET R4
  ADD R4
  PUT R5
  GET R5
  ST R7, 6

  ; Load a = operand[j] into R1:R2 and b = operand[k] into R4:R3.
  LD R6, 0
  PUT R1
  LD R6, 1
  PUT R2
  LD R5, 0
  PUT R4
  LD R5, 1
  PUT R3

  ; Signed ordering:
  ; if signs differ, positive operand is greater;
  ; if signs match, compare high byte then low byte as unsigned values.
  GET R1
  LSL
  JC a_negative, R5
a_nonnegative:
  GET R4
  LSL
  JC a_ge_b, R5
  JMP same_sign, R5
a_negative:
  GET R4
  LSL
  JNC b_greater, R5

same_sign:
  GET R1
  CMP R4
  JC b_greater, R5
  JNZ a_ge_b, R5
  GET R2
  CMP R3
  JC b_greater, R5
  BRA a_ge_b

a_ge_b:
  ; Current distance = a - b, stored in scratch[6:7].
  GET R2
  CLC
  SUB R3
  ST R7, 7
  LD R6, 0
  SUBB R4
  ST R7, 6
  JMP update_min, R5

b_greater:
  ; Current distance = b - a, stored in scratch[6:7].
  GET R3
  CLC
  SUB R2
  ST R7, 7
  LD R7, 6
  PUT R5
  LD R5, 0
  SUBB R1
  ST R7, 6

update_min:
  ; Unsigned 16-bit min compare: high byte first, then low byte on tie.
  LD R7, 6
  PUT R1
  LD R7, 2
  CMP R1
  JC min_keep, R5
  JNZ min_update, R5
  LD R7, 7
  PUT R1
  LD R7, 3
  CMP R1
  JC min_keep, R5
  JZ min_keep, R5
min_update:
  LD R7, 6
  ST R7, 2
  LD R7, 7
  ST R7, 3
min_keep:

update_max:
  ; Unsigned 16-bit max compare: high byte first, then low byte on tie.
  LD R7, 6
  PUT R1
  LD R7, 4
  CMP R1
  JC max_update, R5
  JNZ max_keep, R5
  LD R7, 7
  PUT R1
  LD R7, 5
  CMP R1
  JC max_update, R5
  JMP max_keep, R5
max_update:
  LD R7, 6
  ST R7, 4
  LD R7, 7
  ST R7, 5
max_keep:

  ; k++ and continue the inner loop.
  LI 1
  PUT R5
  LD R7, 1
  ADD R5
  ST R7, 1
  JMP inner_loop, R5

next_j:
  ; j++ and start the next outer-loop row.
  LI 1
  PUT R5
  LD R7, 0
  ADD R5
  ST R7, 0
  JMP outer_loop, R5

finish:
  ; Store min/max to required big-endian output addresses core[66:69].
  LI 66
  PUT R6
  LD R7, 2
  ST R6, 0
  LD R7, 3
  ST R6, 1
  LD R7, 4
  ST R6, 2
  LD R7, 5
  ST R6, 3
  HALT
