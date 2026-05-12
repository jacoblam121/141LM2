module aria_branch(
  input  logic [2:0] cond,
  input  logic       z,
  input  logic       n,
  input  logic       c,
  output logic       taken
);

  always @* begin
    case (cond)
      3'd0: taken = 1'b1;
      3'd1: taken = z;
      3'd2: taken = !z;
      3'd3: taken = c;
      3'd4: taken = !c;
      3'd5: taken = n;
      3'd6: taken = !n;
      3'd7: taken = 1'b0;
      default: taken = 1'b0;
    endcase
  end

endmodule
