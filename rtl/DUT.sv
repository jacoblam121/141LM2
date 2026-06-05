module DUT #(
`ifdef PROG2
  parameter int PROGRAM_ID = 2
`elsif PROG3
  parameter int PROGRAM_ID = 3
`else
  parameter int PROGRAM_ID = 1
`endif
)(
  input  logic clk,
  input  logic start,
  output logic done
);

  logic start_reset;

  assign start_reset = start;

  logic       dm_wen;
  logic [7:0] dm_addr;
  logic [7:0] dm_dat_in;
  logic [7:0] dm_dat_out;

  dat_mem dm(
    .clk(clk),
    .wen(dm_wen),
    .addr(dm_addr),
    .dat_in(dm_dat_in),
    .dat_out(dm_dat_out)
  );

  logic [9:0] pc;
  logic [8:0] inst;

  aria_imem #(.PROGRAM_ID(PROGRAM_ID)) imem(
    .addr(pc),
    .inst(inst)
  );

  aria_fmt_t fmt;
  logic [3:0] alu_op;
  logic [2:0] reg_sel;
  logic [2:0] cond;
  logic [5:0] imm6;
  logic [2:0] special_op;
  logic       dec_mem_write;

  aria_decoder decoder(
    .inst(inst),
    .fmt(fmt),
    .alu_op(alu_op),
    .reg_sel(reg_sel),
    .cond(cond),
    .imm6(imm6),
    .special_op(special_op),
    .mem_write(dec_mem_write)
  );

  logic       z_flag;
  logic       n_flag;
  logic       c_flag;
  logic       branch_taken;
  logic       jr_en;
  logic [1:0] pc_page;

  logic       rf_wen;
  logic [2:0] rf_raddr_a;
  logic [2:0] rf_raddr_b;
  logic [2:0] rf_waddr;
  logic [7:0] rf_wdata;
  logic [7:0] rf_rdata_a;
  logic [7:0] rf_rdata_b;

  aria_branch branch_unit(
    .cond(cond),
    .z(z_flag),
    .n(n_flag),
    .c(c_flag),
    .taken(branch_taken)
  );

  aria_pc pc_unit(
    .clk(clk),
    .reset(start_reset),
    .halt(done || (fmt == FMT_SPECIAL && special_op == 3'd2)),
    .branch_taken(fmt == FMT_BRANCH && branch_taken),
    .branch_offset(inst[3:0]),
    .jr_en(jr_en),
    .pc_page(pc_page),
    .jr_addr(rf_rdata_b),
    .pc(pc)
  );

  aria_reg_file rf(
    .clk(clk),
    .reset(start_reset),
    .wen(rf_wen),
    .raddr_a(rf_raddr_a),
    .raddr_b(rf_raddr_b),
    .waddr(rf_waddr),
    .wdata(rf_wdata),
    .rdata_a(rf_rdata_a),
    .rdata_b(rf_rdata_b)
  );

  logic [7:0] alu_result;
  logic       alu_z;
  logic       alu_n;
  logic       alu_c;

  aria_alu alu(
    .op(alu_op),
    .acc(rf_rdata_a),
    .src(rf_rdata_b),
    .carry_in(c_flag),
    .result(alu_result),
    .z(alu_z),
    .n(alu_n),
    .c(alu_c)
  );

  logic       is_alu;
  logic       is_cmp;
  logic       is_ld;
  logic       is_st;
  logic       is_ldi;
  logic       is_put;
  logic       is_set6;
  logic       is_set7;
  logic [7:0] mem_offset;
  logic [2:0] mem_base_sel;

  assign is_alu  = fmt == FMT_ALU;
  assign is_cmp  = is_alu && alu_op == 4'h7;
  assign is_ld   = fmt == FMT_MEM && inst[6];
  assign is_st   = fmt == FMT_MEM && !inst[6];
  assign is_ldi  = fmt == FMT_LDI;
  assign is_put  = fmt == FMT_SPECIAL && special_op == 3'd0;
  assign jr_en   = fmt == FMT_SPECIAL && special_op == 3'd1;
  assign is_set6 = fmt == FMT_SPECIAL && special_op == 3'd4;
  assign is_set7 = fmt == FMT_SPECIAL && special_op == 3'd5;
  assign mem_offset = {5'd0, inst[2:0]};
  assign mem_base_sel = inst[5:3];

  always_comb begin
    rf_raddr_a = 3'd0;
    rf_raddr_b = (fmt == FMT_MEM) ? mem_base_sel : reg_sel;
    rf_waddr   = 3'd0;
    rf_wdata   = 8'd0;
    rf_wen     = 1'b0;

    dm_addr   = rf_rdata_b + mem_offset;
    dm_dat_in = rf_rdata_a;
    dm_wen    = is_st && !done && !start_reset;

    if (!done && !start_reset) begin
      case (fmt)
        FMT_ALU: begin
          rf_wen   = !is_cmp;
          rf_waddr = 3'd0;
          rf_wdata = alu_result;
        end
        FMT_MEM: begin
          rf_wen   = is_ld;
          rf_waddr = 3'd0;
          rf_wdata = dm_dat_out;
        end
        FMT_LDI: begin
          rf_wen   = 1'b1;
          rf_waddr = 3'd0;
          rf_wdata = {2'b00, imm6};
        end
        FMT_SPECIAL: begin
          case (special_op)
            3'd0: begin
              rf_wen   = 1'b1;
              rf_waddr = reg_sel;
              rf_wdata = rf_rdata_a;
            end
            3'd4: begin
              rf_wen   = 1'b1;
              rf_waddr = 3'd0;
              rf_wdata = rf_rdata_a | 8'h40;
            end
            3'd5: begin
              rf_wen   = 1'b1;
              rf_waddr = 3'd0;
              rf_wdata = rf_rdata_a | 8'h80;
            end
            default: begin
              rf_wen   = 1'b0;
              rf_waddr = 3'd0;
              rf_wdata = 8'd0;
            end
          endcase
        end
        default: begin
          rf_wen   = 1'b0;
          rf_waddr = 3'd0;
          rf_wdata = 8'd0;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (start_reset) begin
      done    <= 1'b0;
      z_flag  <= 1'b0;
      n_flag  <= 1'b0;
      c_flag  <= 1'b0;
      pc_page <= 2'd0;
    end else if (!done) begin
      if (is_alu) begin
        z_flag <= alu_z;
        n_flag <= alu_n;
        c_flag <= alu_c;
      end else if (fmt == FMT_SPECIAL && special_op == 3'd7) begin
        c_flag <= 1'b0;
      end

      if (fmt == FMT_SPECIAL && special_op == 3'd6) begin
        pc_page <= reg_sel[1:0];
      end

      if (fmt == FMT_SPECIAL && special_op == 3'd2) begin
        done <= 1'b1;
      end
    end
  end

endmodule
