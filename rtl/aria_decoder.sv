typedef enum logic [2:0] {
  FMT_ALU,
  FMT_MEM,
  FMT_BRANCH,
  FMT_LDI,
  FMT_SPECIAL
} aria_fmt_t;

module aria_decoder(
  input  logic [8:0] inst,
  output aria_fmt_t  fmt,
  output logic [3:0] alu_op,
  output logic [2:0] reg_sel,
  output logic [2:0] cond,
  output logic [5:0] imm6,
  output logic [2:0] special_op,
  output logic       mem_write
);

  always @* begin
    fmt        = FMT_SPECIAL;
    alu_op     = inst[6:3];
    reg_sel    = inst[2:0];
    cond       = inst[6:4];
    imm6       = inst[5:0];
    special_op = inst[5:3];
    mem_write  = inst[6];

    case (inst[8:7])
      2'b00: fmt = FMT_ALU;
      2'b01: fmt = FMT_MEM;
      2'b10: fmt = FMT_BRANCH;
      2'b11: begin
        if (inst[6]) begin
          fmt = FMT_SPECIAL;
        end else begin
          fmt = FMT_LDI;
        end
      end
      default: fmt = FMT_SPECIAL;
    endcase
  end

endmodule
