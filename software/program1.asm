; Program 1: minimum and maximum Hamming distance across 32 16-bit operands.
; Scratch at R7=128: [0]=j, [1]=k, [2]=min, [3]=max, [4]=bit count.

start:
  ; Initialize scratch base, constant 1, j, min, and max.
  LI 128
  PUT R7
  LI 1
  PUT R3
  LI 0
  ST R7, 0
  LI 16
  ST R7, 2
  LI 0
  ST R7, 3

outer_loop:
  ; Stop once j reaches 31; the final useful outer value is j=30.
  LD R7, 0
  PUT R4
  LDI 31
  CMP R4
  JZ finish, R6

  ; R6 = address of operand[j] high byte = 2*j.
  GET R4
  ADD R4
  PUT R6

  ; k starts at j+1 for each outer-loop iteration.
  GET R4
  ADD R3
  ST R7, 1

inner_loop:
  ; Stop inner loop once k reaches 32.
  LD R7, 1
  PUT R4
  LDI 32
  CMP R4
  JZ next_j, R5

  ; R5 = address of operand[k] high byte = 2*k.
  GET R4
  ADD R4
  PUT R5

  ; R1 accumulates the Hamming distance for this pair.
  LI 0
  PUT R1

  ; XOR the high bytes and count the set bits in an 8-cycle loop.
  LD R6, 0
  PUT R4
  LD R5, 0
  XOR R4
  PUT R4

  LI 16
  LSR
  ST R7, 4
count_hi_loop:
  GET R4
  LSR
  PUT R4
  BNC count_hi_skip
  GET R1
  ADD R3
  PUT R1
count_hi_skip:
  LD R7, 4
  SUB R3
  ST R7, 4
  JNZ count_hi_loop, R2

low_byte:
  ; XOR the low bytes and count the set bits in an 8-cycle loop.
  LD R6, 1
  PUT R4
  LD R5, 1
  XOR R4
  PUT R4

  LI 16
  LSR
  ST R7, 4
count_lo_loop:
  GET R4
  LSR
  PUT R4
  BNC count_lo_skip
  GET R1
  ADD R3
  PUT R1
count_lo_skip:
  LD R7, 4
  SUB R3
  ST R7, 4
  JNZ count_lo_loop, R2

update_min:
  ; If current distance R1 is smaller than min, replace min.
  LD R7, 2
  CMP R1
  BZ min_done
  BC min_done
  GET R1
  ST R7, 2
min_done:
  ; If current distance R1 is larger than max, replace max.
  LD R7, 3
  CMP R1
  BNC max_done
  GET R1
  ST R7, 3
max_done:
  ; k++ and continue the inner pair loop.
  LD R7, 1
  ADD R3
  ST R7, 1
  JMP inner_loop, R5

next_j:
  ; j++ and start the next outer-loop row.
  LD R7, 0
  ADD R3
  ST R7, 0
  JMP outer_loop, R5

finish:
  ; Store min/max to required output addresses core[64] and core[65].
  LI 64
  PUT R6
  LD R7, 2
  ST R6, 0
  LD R7, 3
  ST R6, 1
  HALT
