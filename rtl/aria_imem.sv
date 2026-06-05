module aria_imem(
  input  logic [9:0] addr,
  output logic [8:0] inst
);

  logic [8:0] core[0:1023];
  int i;

  initial begin
    for (i = 0; i < 1024; i++) begin
      core[i] = 9'b111_010_000; // HALT
    end
    $readmemb("program.mem", core);
  end

  assign inst = core[addr];

endmodule
