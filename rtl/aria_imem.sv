module aria_imem(
  input  logic [9:0] addr,
  input  logic [1:0] program_sel,
  output logic [8:0] inst
);

  logic [8:0] core[0:1023];
`ifdef COMBINED
  logic [8:0] core1[0:1023];
  logic [8:0] core2[0:1023];
  logic [8:0] core3[0:1023];
`endif
  int i;

  initial begin
    for (i = 0; i < 1024; i++) begin
      core[i] = 9'b111_010_000; // HALT
`ifdef COMBINED
      core1[i] = 9'b111_010_000;
      core2[i] = 9'b111_010_000;
      core3[i] = 9'b111_010_000;
`endif
    end

`ifdef COMBINED
    $readmemb("software/program1.mem", core1);
    $readmemb("software/program2.mem", core2);
    $readmemb("software/program3.mem", core3);
`elsif PROG1
    $readmemb("software/program1.mem", core);
`elsif PROG2
    $readmemb("software/program2.mem", core);
`elsif PROG3
    $readmemb("software/program3.mem", core);
`else
    $readmemb("program.mem", core);
`endif
  end

`ifdef COMBINED
  always_comb begin
    case (program_sel)
      2'd0: inst = core1[addr];
      2'd1: inst = core2[addr];
      2'd2: inst = core3[addr];
      default: inst = 9'b111_010_000;
    endcase
  end
`else
  assign inst = core[addr];
`endif

endmodule
