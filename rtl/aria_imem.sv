module aria_imem #(
  parameter int PROGRAM_ID = 1
)(
  input  logic [9:0] addr,
  output logic [8:0] inst
);

  always @* begin
    inst = 9'b111_000_000; // HALT for unused ROM.
    case (PROGRAM_ID)
      1: begin
        case (addr)
          10'd0: inst = 9'b110_000000; // LDI 0
          10'd1: inst = 9'b111_000_000; // HALT
          default: inst = 9'b111_000_000;
        endcase
      end
      2: begin
        case (addr)
          10'd0: inst = 9'b110_000000;
          10'd1: inst = 9'b111_000_000;
          default: inst = 9'b111_000_000;
        endcase
      end
      3: begin
        case (addr)
          10'd0: inst = 9'b110_000000;
          10'd1: inst = 9'b111_000_000;
          default: inst = 9'b111_000_000;
        endcase
      end
      default: inst = 9'b111_000_000;
    endcase
  end

endmodule
