module aria_reg_file(
  input  logic       clk,
  input  logic       start,
  input  logic       wen,
  input  logic [2:0] raddr_a,
  input  logic [2:0] raddr_b,
  input  logic [2:0] waddr,
  input  logic [7:0] wdata,
  output logic [7:0] rdata_a,
  output logic [7:0] rdata_b
);

  logic [7:0] regs[8];
  int i;

  always_ff @(posedge clk) begin
    if (start) begin
      for (i = 0; i < 8; i++) begin
        regs[i] <= 8'd0;
      end
    end else if (wen) begin
      regs[waddr] <= wdata;
    end
  end

  assign rdata_a = regs[raddr_a];
  assign rdata_b = regs[raddr_b];

endmodule
