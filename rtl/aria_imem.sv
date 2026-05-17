module aria_imem #(
  parameter int PROGRAM_ID = 1
)(
  input  logic [9:0] addr,
  output logic [8:0] inst
);

  logic [8:0] rom[1024];
  int i;

  initial begin
    for (i = 0; i < 1024; i++) begin
      rom[i] = 9'b111_010_000; // HALT
    end
`ifdef NO_IMEM_LOAD
    ;
`elsif PROG1
    $readmemb("../../software/program1.mem", rom);
`elsif PROG2
    $readmemb("../../software/program2.mem", rom);
`elsif PROG3
    $readmemb("../../software/program3.mem", rom);
`else
    case (PROGRAM_ID)
      1: $readmemb("../../software/program1.mem", rom);
      2: $readmemb("../../software/program2.mem", rom);
      3: $readmemb("../../software/program3.mem", rom);
      default: ;
    endcase
`endif
  end

  assign inst = rom[addr];

endmodule
