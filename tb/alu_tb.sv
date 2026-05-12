module alu_tb;
  logic [3:0] op;
  logic [7:0] acc;
  logic [7:0] src;
  logic       carry_in;
  logic [7:0] result;
  logic       z;
  logic       n;
  logic       c;
  int         errors;

  aria_alu dut(
    .op(op),
    .acc(acc),
    .src(src),
    .carry_in(carry_in),
    .result(result),
    .z(z),
    .n(n),
    .c(c)
  );

  task automatic check(
    input logic [3:0] t_op,
    input logic [7:0] t_acc,
    input logic [7:0] t_src,
    input logic       t_cin,
    input logic [7:0] exp_result,
    input logic       exp_z,
    input logic       exp_n,
    input logic       exp_c,
    input string      name
  );
    begin
      op = t_op;
      acc = t_acc;
      src = t_src;
      carry_in = t_cin;
      #1;
      if (result !== exp_result || z !== exp_z || n !== exp_n || c !== exp_c) begin
        $display("FAIL %s: got result=%h z=%b n=%b c=%b expected result=%h z=%b n=%b c=%b",
                 name, result, z, n, c, exp_result, exp_z, exp_n, exp_c);
        errors++;
      end
    end
  endtask

  initial begin
    errors = 0;

    check(4'h0, 8'hfe, 8'h03, 1'b0, 8'h01, 1'b0, 1'b0, 1'b1, "ADD");
    check(4'h1, 8'h7f, 8'h00, 1'b1, 8'h80, 1'b0, 1'b1, 1'b0, "ADDC");
    check(4'h2, 8'h03, 8'h05, 1'b0, 8'hfe, 1'b0, 1'b1, 1'b1, "SUB");
    check(4'h3, 8'h05, 8'h04, 1'b1, 8'h00, 1'b1, 1'b0, 1'b0, "SUBB");
    check(4'h4, 8'ha5, 8'h0f, 1'b0, 8'h05, 1'b0, 1'b0, 1'b0, "AND");
    check(4'h5, 8'ha0, 8'h0f, 1'b0, 8'haf, 1'b0, 1'b1, 1'b0, "OR");
    check(4'h6, 8'haa, 8'hff, 1'b0, 8'h55, 1'b0, 1'b0, 1'b0, "XOR");
    check(4'h7, 8'h10, 8'h10, 1'b0, 8'h00, 1'b1, 1'b0, 1'b0, "CMP");
    check(4'h8, 8'h81, 8'h00, 1'b0, 8'h02, 1'b0, 1'b0, 1'b1, "LSL");
    check(4'h9, 8'h03, 8'h00, 1'b0, 8'h01, 1'b0, 1'b0, 1'b1, "LSR");
    check(4'ha, 8'h80, 8'h00, 1'b1, 8'h01, 1'b0, 1'b0, 1'b1, "ROL");
    check(4'hb, 8'h01, 8'h00, 1'b1, 8'h80, 1'b0, 1'b1, 1'b1, "ROR");
    check(4'hc, 8'h55, 8'h00, 1'b0, 8'haa, 1'b0, 1'b1, 1'b0, "NOT");
    check(4'hd, 8'h01, 8'h00, 1'b0, 8'hff, 1'b0, 1'b1, 1'b0, "NEG");
    check(4'he, 8'hab, 8'h00, 1'b0, 8'h00, 1'b1, 1'b0, 1'b0, "CLR");
    check(4'hf, 8'h00, 8'h3c, 1'b0, 8'h3c, 1'b0, 1'b0, 1'b0, "GET");

    if (errors == 0) begin
      $display("ALU PASS");
    end else begin
      $display("ALU FAIL errors=%0d", errors);
    end
    $finish;
  end
endmodule
