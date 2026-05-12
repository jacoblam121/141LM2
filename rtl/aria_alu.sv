module aria_alu(
  input  logic [3:0] op,
  input  logic [7:0] acc,
  input  logic [7:0] src,
  input  logic       carry_in,
  output logic [7:0] result,
  output logic       z,
  output logic       n,
  output logic       c
);

  logic [8:0] tmp;

  always @* begin
    tmp    = 9'd0;
    result = 8'd0;
    c      = 1'b0;

    case (op)
      4'h0: begin
        tmp    = {1'b0, acc} + {1'b0, src};
        result = tmp[7:0];
        c      = tmp[8];
      end
      4'h1: begin
        tmp    = {1'b0, acc} + {1'b0, src} + {8'd0, carry_in};
        result = tmp[7:0];
        c      = tmp[8];
      end
      4'h2: begin
        tmp    = {1'b0, acc} - {1'b0, src};
        result = tmp[7:0];
        c      = acc < src;
      end
      4'h3: begin
        tmp    = {1'b0, acc} - {1'b0, src} - {8'd0, carry_in};
        result = tmp[7:0];
        c      = {1'b0, acc} < ({1'b0, src} + {8'd0, carry_in});
      end
      4'h4: result = acc & src;
      4'h5: result = acc | src;
      4'h6: result = acc ^ src;
      4'h7: begin
        tmp    = {1'b0, acc} - {1'b0, src};
        result = tmp[7:0];
        c      = acc < src;
      end
      4'h8: begin
        result = {acc[6:0], 1'b0};
        c      = acc[7];
      end
      4'h9: begin
        result = {1'b0, acc[7:1]};
        c      = acc[0];
      end
      4'ha: begin
        result = {acc[6:0], carry_in};
        c      = acc[7];
      end
      4'hb: begin
        result = {carry_in, acc[7:1]};
        c      = acc[0];
      end
      4'hc: result = ~acc;
      4'hd: result = ~acc + 8'd1;
      4'he: result = 8'd0;
      4'hf: result = src;
      default: result = 8'd0;
    endcase
  end

  assign z = result == 8'd0;
  assign n = result[7];

endmodule
