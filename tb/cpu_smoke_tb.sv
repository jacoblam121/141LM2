module cpu_smoke_tb;
  logic clk;
  logic start;
  logic done;
  int   errors;
  int   i;

  DUT dut(
    .clk(clk),
    .start(start),
    .done(done)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    start = 1'b1;
    errors = 0;

    #1;
    for (i = 0; i < 1024; i++) begin
      dut.imem.rom[i] = 9'b111_010_000;
    end
    dut.imem.rom[0]  = 9'b110_000101; // LDI 5
    dut.imem.rom[1]  = 9'b111_000_001; // PUT R1
    dut.imem.rom[2]  = 9'b110_001010; // LDI 10
    dut.imem.rom[3]  = 9'b010_001_000; // ST R1,0
    dut.imem.rom[4]  = 9'b011_001_000; // LD R1,0
    dut.imem.rom[5]  = 9'b111_000_010; // PUT R2
    dut.imem.rom[6]  = 9'b110_001010; // LDI 10
    dut.imem.rom[7]  = 9'b000_111_010; // CMP R2
    dut.imem.rom[8]  = 9'b100_010_011; // BNZ +3
    dut.imem.rom[9]  = 9'b110_000000; // LDI 0
    dut.imem.rom[10] = 9'b000_111_011; // CMP R3
    dut.imem.rom[11] = 9'b100_000_001; // BZ +1
    dut.imem.rom[12] = 9'b111_010_000; // HALT on failure
    dut.imem.rom[13] = 9'b111_111_000; // CLC
    dut.imem.rom[14] = 9'b101_010_001; // BNC +1
    dut.imem.rom[15] = 9'b111_010_000; // HALT on failure
    dut.imem.rom[16] = 9'b110_100000; // LDI 32
    dut.imem.rom[17] = 9'b111_000_100; // PUT R4
    dut.imem.rom[18] = 9'b111_110_000; // SETP 0
    dut.imem.rom[19] = 9'b111_001_100; // JR R4
    dut.imem.rom[20] = 9'b111_011_000; // NOP
    dut.imem.rom[32] = 9'b111_011_000; // NOP
    dut.imem.rom[33] = 9'b110_101010; // LDI 42
    dut.imem.rom[34] = 9'b111_000_110; // PUT R6
    dut.imem.rom[35] = 9'b110_010100; // LDI 20
    dut.imem.rom[36] = 9'b111_000_111; // PUT R7
    dut.imem.rom[37] = 9'b001_111_110; // GET R6
    dut.imem.rom[38] = 9'b010_111_000; // ST R7,0
    dut.imem.rom[39] = 9'b111_010_000; // HALT

    repeat (2) @(posedge clk);
    start = 1'b0;
    wait(done);
    #1;

    if (dut.dm.core[5] !== 8'd10) begin
      $display("FAIL data memory store/load: got %h", dut.dm.core[5]);
      errors++;
    end
    if (dut.dm.core[20] !== 8'd42) begin
      $display("FAIL branch/jr path: got %h", dut.dm.core[20]);
      errors++;
    end

    if (errors == 0) begin
      $display("CPU SMOKE PASS");
    end else begin
      $display("CPU SMOKE FAIL errors=%0d", errors);
    end
    $finish;
  end
endmodule
