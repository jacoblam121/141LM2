module pc_tb;
  logic clk;
  logic reset;
  logic halt;
  logic branch_taken;
  logic signed [3:0] branch_offset;
  logic jr_en;
  logic [1:0] pc_page;
  logic [7:0] jr_addr;
  logic [9:0] pc;
  int errors;

  aria_pc dut(
    .clk(clk),
    .reset(reset),
    .halt(halt),
    .branch_taken(branch_taken),
    .branch_offset(branch_offset),
    .jr_en(jr_en),
    .pc_page(pc_page),
    .jr_addr(jr_addr),
    .pc(pc)
  );

  always #5 clk = ~clk;

  task automatic step;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check_pc(input logic [9:0] exp, input string name);
    begin
      if (pc !== exp) begin
        $display("FAIL %s: got pc=%0d expected pc=%0d", name, pc, exp);
        errors++;
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    halt = 1'b0;
    branch_taken = 1'b0;
    branch_offset = 4'sd0;
    jr_en = 1'b0;
    pc_page = 2'd0;
    jr_addr = 8'd0;
    errors = 0;

    step();
    check_pc(10'd0, "start reset");

    reset = 1'b0;
    step();
    check_pc(10'd1, "increment 1");
    step();
    check_pc(10'd2, "increment 2");

    branch_taken = 1'b1;
    branch_offset = 4'sd3;
    step();
    check_pc(10'd6, "positive branch from pc+1");

    branch_offset = -4'sd2;
    step();
    check_pc(10'd5, "negative branch from pc+1");

    branch_taken = 1'b0;
    step();
    check_pc(10'd6, "branch not taken");

    jr_en = 1'b1;
    pc_page = 2'b10;
    jr_addr = 8'h34;
    step();
    check_pc(10'h234, "jr page target");

    jr_en = 1'b0;
    halt = 1'b1;
    step();
    check_pc(10'h234, "halt hold");

    halt = 1'b0;
    jr_en = 1'b1;
    pc_page = 2'b11;
    jr_addr = 8'hff;
    step();
    check_pc(10'h3ff, "jr max");

    jr_en = 1'b0;
    step();
    check_pc(10'd0, "pc wrap");

    if (errors == 0) begin
      $display("PC PASS");
    end else begin
      $display("PC FAIL errors=%0d", errors);
    end
    $finish;
  end
endmodule
