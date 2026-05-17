module aria_branch(
  input  logic [2:0] cond,
  input  logic       z,
  input  logic       n,
  input  logic       c,
  output logic       taken
);

  always @* begin
    case (cond)
      3'd0: taken = z;     // BZ
      3'd1: taken = !z;    // BNZ
      3'd2: taken = n;     // BN
      3'd3: taken = !n;    // BNN
      3'd4: taken = c;     // BC
      3'd5: taken = !c;    // BNC
      3'd6: taken = 1'b1;  // BRA
      3'd7: taken = 1'b0;
      default: taken = 1'b0;
    endcase
  end

endmodule
