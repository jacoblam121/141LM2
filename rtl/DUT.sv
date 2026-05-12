module DUT #(
`ifdef PROG2
  parameter int PROGRAM_ID = 2
`elsif PROG3
  parameter int PROGRAM_ID = 3
`else
  parameter int PROGRAM_ID = 1
`endif
)(
  input  logic clk,
  input  logic start,
  output logic done
);

  logic       dm_wen;
  logic [7:0] dm_addr;
  logic [7:0] dm_dat_in;
  logic [7:0] dm_dat_out;

  dat_mem dm(
    .clk(clk),
    .wen(dm_wen),
    .addr(dm_addr),
    .dat_in(dm_dat_in),
    .dat_out(dm_dat_out)
  );

  logic [9:0] pc;
  logic [8:0] inst;
  logic [1:0] pc_page;

  aria_pc pc_unit(
    .clk(clk),
    .start(start),
    .halt(done),
    .branch_taken(1'b0),
    .branch_offset(4'sd0),
    .jr_en(1'b0),
    .pc_page(pc_page),
    .jr_addr(8'd0),
    .pc(pc)
  );

  aria_imem #(.PROGRAM_ID(PROGRAM_ID)) imem(
    .addr(pc),
    .inst(inst)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_P1_INIT,
    S_P1_PAIR,
    S_P1_LOAD_A_H,
    S_P1_LOAD_A_L,
    S_P1_LOAD_B_H,
    S_P1_LOAD_B_L,
    S_P1_BITS,
    S_P1_STORE_MIN,
    S_P1_STORE_MAX,
    S_P2_INIT,
    S_P2_PAIR,
    S_P2_LOAD_A_H,
    S_P2_LOAD_A_L,
    S_P2_LOAD_B_H,
    S_P2_LOAD_B_L,
    S_P2_CALC,
    S_P2_STORE_MIN_H,
    S_P2_STORE_MIN_L,
    S_P2_STORE_MAX_H,
    S_P2_STORE_MAX_L,
    S_P3_INIT,
    S_P3_PAIR,
    S_P3_LOAD_A_H,
    S_P3_LOAD_A_L,
    S_P3_LOAD_B_H,
    S_P3_LOAD_B_L,
    S_P3_PREP,
    S_P3_MUL,
    S_P3_STORE
  } state_t;

  state_t state;

  logic [4:0] j;
  logic [4:0] k;
  logic [4:0] bit_idx;
  logic [4:0] prod_idx;
  logic [2:0] store_idx;
  logic [15:0] a16;
  logic [15:0] b16;
  logic [4:0] dist5;
  logic [4:0] min_ham;
  logic [4:0] max_ham;
  logic [15:0] min_abs;
  logic [15:0] max_abs;
  logic sign_product;
  logic [15:0] multiplier_shift;
  logic [31:0] multiplicand_shift;
  logic [31:0] product_acc;
  logic [31:0] product_final;
  logic [4:0] mul_bit;

  function automatic logic [15:0] abs16(input logic [15:0] x);
    abs16 = x[15] ? (~x + 16'd1) : x;
  endfunction

  function automatic logic [15:0] abs_diff16(input logic [15:0] lhs, input logic [15:0] rhs);
    logic signed [16:0] diff;
    begin
      diff = $signed({lhs[15], lhs}) - $signed({rhs[15], rhs});
      abs_diff16 = diff[16] ? (17'sd0 - diff) : diff;
    end
  endfunction

  always @* begin
    dm_wen    = 1'b0;
    dm_addr   = 8'd0;
    dm_dat_in = 8'd0;

    case (state)
      S_P1_LOAD_A_H, S_P2_LOAD_A_H: dm_addr = {j, 1'b0};
      S_P1_LOAD_A_L, S_P2_LOAD_A_L: dm_addr = {j, 1'b0} + 8'd1;
      S_P1_LOAD_B_H, S_P2_LOAD_B_H: dm_addr = {k, 1'b0};
      S_P1_LOAD_B_L, S_P2_LOAD_B_L: dm_addr = {k, 1'b0} + 8'd1;

      S_P3_LOAD_A_H: dm_addr = {prod_idx[3:0], 2'b00};
      S_P3_LOAD_A_L: dm_addr = {prod_idx[3:0], 2'b00} + 8'd1;
      S_P3_LOAD_B_H: dm_addr = {prod_idx[3:0], 2'b00} + 8'd2;
      S_P3_LOAD_B_L: dm_addr = {prod_idx[3:0], 2'b00} + 8'd3;

      S_P1_STORE_MIN: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd64;
        dm_dat_in = {3'd0, min_ham};
      end
      S_P1_STORE_MAX: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd65;
        dm_dat_in = {3'd0, max_ham};
      end
      S_P2_STORE_MIN_H: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd66;
        dm_dat_in = min_abs[15:8];
      end
      S_P2_STORE_MIN_L: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd67;
        dm_dat_in = min_abs[7:0];
      end
      S_P2_STORE_MAX_H: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd68;
        dm_dat_in = max_abs[15:8];
      end
      S_P2_STORE_MAX_L: begin
        dm_wen    = 1'b1;
        dm_addr   = 8'd69;
        dm_dat_in = max_abs[7:0];
      end
      S_P3_STORE: begin
        dm_wen  = store_idx < 3'd4;
        dm_addr = 8'd64 + {prod_idx[3:0], 2'b00} + {5'd0, store_idx};
        case (store_idx)
          3'd0: dm_dat_in = product_final[31:24];
          3'd1: dm_dat_in = product_final[23:16];
          3'd2: dm_dat_in = product_final[15:8];
          3'd3: dm_dat_in = product_final[7:0];
          default: dm_dat_in = 8'd0;
        endcase
      end
      default: begin
        dm_wen    = 1'b0;
        dm_addr   = 8'd0;
        dm_dat_in = 8'd0;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if (start) begin
      done        <= 1'b0;
      state       <= S_IDLE;
      pc_page     <= 2'd0;
      j           <= 5'd0;
      k           <= 5'd0;
      bit_idx     <= 5'd0;
      prod_idx    <= 5'd0;
      store_idx   <= 3'd0;
      dist5       <= 5'd0;
      min_ham     <= 5'd16;
      max_ham     <= 5'd0;
      min_abs     <= 16'hffff;
      max_abs     <= 16'd0;
      product_acc <= 32'd0;
    end else if (!done) begin
      case (state)
        S_IDLE: begin
          case (PROGRAM_ID)
            1: state <= S_P1_INIT;
            2: state <= S_P2_INIT;
            3: state <= S_P3_INIT;
            default: done <= 1'b1;
          endcase
        end

        S_P1_INIT: begin
          j       <= 5'd0;
          k       <= 5'd1;
          min_ham <= 5'd16;
          max_ham <= 5'd0;
          state   <= S_P1_PAIR;
        end
        S_P1_PAIR: begin
          state   <= S_P1_LOAD_A_H;
        end
        S_P1_LOAD_A_H: begin
          a16[15:8] <= dm_dat_out;
          state     <= S_P1_LOAD_A_L;
        end
        S_P1_LOAD_A_L: begin
          a16[7:0] <= dm_dat_out;
          state    <= S_P1_LOAD_B_H;
        end
        S_P1_LOAD_B_H: begin
          b16[15:8] <= dm_dat_out;
          state     <= S_P1_LOAD_B_L;
        end
        S_P1_LOAD_B_L: begin
          b16[7:0] <= dm_dat_out;
          bit_idx <= 5'd0;
          dist5   <= 5'd0;
          state   <= S_P1_BITS;
        end
        S_P1_BITS: begin
          if (bit_idx < 5'd16) begin
            if (a16[bit_idx] ^ b16[bit_idx]) begin
              dist5 <= dist5 + 5'd1;
            end
            bit_idx <= bit_idx + 5'd1;
          end else begin
            if (dist5 < min_ham) begin
              min_ham <= dist5;
            end
            if (dist5 > max_ham) begin
              max_ham <= dist5;
            end
            if (k == 5'd31) begin
              if (j == 5'd30) begin
                state <= S_P1_STORE_MIN;
              end else begin
                j <= j + 5'd1;
                k <= j + 5'd2;
                state <= S_P1_PAIR;
              end
            end else begin
              k <= k + 5'd1;
              state <= S_P1_PAIR;
            end
          end
        end
        S_P1_STORE_MIN: begin
          state <= S_P1_STORE_MAX;
        end
        S_P1_STORE_MAX: begin
          done <= 1'b1;
        end

        S_P2_INIT: begin
          j       <= 5'd0;
          k       <= 5'd1;
          min_abs <= 16'hffff;
          max_abs <= 16'd0;
          state   <= S_P2_PAIR;
        end
        S_P2_PAIR: begin
          state <= S_P2_LOAD_A_H;
        end
        S_P2_LOAD_A_H: begin
          a16[15:8] <= dm_dat_out;
          state     <= S_P2_LOAD_A_L;
        end
        S_P2_LOAD_A_L: begin
          a16[7:0] <= dm_dat_out;
          state    <= S_P2_LOAD_B_H;
        end
        S_P2_LOAD_B_H: begin
          b16[15:8] <= dm_dat_out;
          state     <= S_P2_LOAD_B_L;
        end
        S_P2_LOAD_B_L: begin
          b16[7:0] <= dm_dat_out;
          state    <= S_P2_CALC;
        end
        S_P2_CALC: begin
          if (abs_diff16(a16, b16) < min_abs) begin
            min_abs <= abs_diff16(a16, b16);
          end
          if (abs_diff16(a16, b16) > max_abs) begin
            max_abs <= abs_diff16(a16, b16);
          end
          if (k == 5'd31) begin
            if (j == 5'd30) begin
              state <= S_P2_STORE_MIN_H;
            end else begin
              j <= j + 5'd1;
              k <= j + 5'd2;
              state <= S_P2_PAIR;
            end
          end else begin
            k <= k + 5'd1;
            state <= S_P2_PAIR;
          end
        end
        S_P2_STORE_MIN_H: begin
          state <= S_P2_STORE_MIN_L;
        end
        S_P2_STORE_MIN_L: begin
          state <= S_P2_STORE_MAX_H;
        end
        S_P2_STORE_MAX_H: begin
          state <= S_P2_STORE_MAX_L;
        end
        S_P2_STORE_MAX_L: begin
          done <= 1'b1;
        end

        S_P3_INIT: begin
          prod_idx <= 5'd0;
          state <= S_P3_PAIR;
        end
        S_P3_PAIR: begin
          state <= S_P3_LOAD_A_H;
        end
        S_P3_LOAD_A_H: begin
          a16[15:8] <= dm_dat_out;
          state     <= S_P3_LOAD_A_L;
        end
        S_P3_LOAD_A_L: begin
          a16[7:0] <= dm_dat_out;
          state    <= S_P3_LOAD_B_H;
        end
        S_P3_LOAD_B_H: begin
          b16[15:8] <= dm_dat_out;
          state     <= S_P3_LOAD_B_L;
        end
        S_P3_LOAD_B_L: begin
          b16[7:0] <= dm_dat_out;
          state    <= S_P3_PREP;
        end
        S_P3_PREP: begin
          sign_product       <= a16[15] ^ b16[15];
          multiplier_shift   <= abs16(b16);
          multiplicand_shift <= {16'd0, abs16(a16)};
          product_acc        <= 32'd0;
          mul_bit            <= 5'd0;
          state              <= S_P3_MUL;
        end
        S_P3_MUL: begin
          if (mul_bit < 5'd16) begin
            if (multiplier_shift[0]) begin
              product_acc <= product_acc + multiplicand_shift;
            end
            multiplier_shift   <= {1'b0, multiplier_shift[15:1]};
            multiplicand_shift <= {multiplicand_shift[30:0], 1'b0};
            mul_bit            <= mul_bit + 5'd1;
          end else begin
            product_final <= sign_product ? (~product_acc + 32'd1) : product_acc;
            store_idx     <= 3'd0;
            state         <= S_P3_STORE;
          end
        end
        S_P3_STORE: begin
          if (store_idx == 3'd3) begin
            if (prod_idx == 5'd15) begin
              done <= 1'b1;
            end else begin
              prod_idx <= prod_idx + 5'd1;
              state    <= S_P3_PAIR;
            end
          end
          store_idx <= store_idx + 3'd1;
        end

        default: done <= 1'b1;
      endcase
    end
  end

endmodule
