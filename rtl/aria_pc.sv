module aria_pc(
  input  logic        clk,
  input  logic        reset,
  input  logic        halt,
  input  logic        branch_taken,
  input  logic signed [3:0] branch_offset,
  input  logic        jr_en,
  input  logic [1:0]  pc_page,
  input  logic [7:0]  jr_addr,
  output logic [9:0]  pc
);

  logic [9:0] seq_pc;
  logic [9:0] br_pc;

  assign seq_pc = pc + 10'd1;
  assign br_pc  = seq_pc + {{6{branch_offset[3]}}, branch_offset};

  always_ff @(posedge clk) begin
    if (reset) begin
      pc <= 10'd0;
    end else if (halt) begin
      pc <= pc;
    end else if (jr_en) begin
      pc <= {pc_page, jr_addr};
    end else if (branch_taken) begin
      pc <= br_pc;
    end else begin
      pc <= seq_pc;
    end
  end

endmodule
