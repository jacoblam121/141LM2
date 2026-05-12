module dat_mem(
  input  logic       clk,
  input  logic       wen,
  input  logic [7:0] addr,
  input  logic [7:0] dat_in,
  output logic [7:0] dat_out
);

  logic [7:0] core[256];

  always_ff @(posedge clk) begin
    if (wen) begin
      core[addr] <= dat_in;
    end
  end

  assign dat_out = core[addr];

endmodule
