module attention_core #(
  parameter int N_MAX      = 16,
  parameter int D_MAX      = 32,
  parameter int DATA_WIDTH = 8,
  parameter int ACC_WIDTH  = 32
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         start,
  input  logic [3:0]                   n_val,
  input  logic [4:0]                   d_val,

  output logic [4:0]                   q_addr,
  output logic                         q_re,
  input  logic signed [DATA_WIDTH-1:0] q_rdata,

  output logic [8:0]                   k_addr,
  output logic                         k_re,
  input  logic signed [DATA_WIDTH-1:0] k_rdata,

  output logic [8:0]                   v_addr,
  output logic                         v_re,
  input  logic signed [DATA_WIDTH-1:0] v_rdata,

  output logic [3:0]                   result_idx,
  output logic signed [DATA_WIDTH-1:0] result_out [0:D_MAX-1],
  output logic                         done,
  output logic                         busy
);

  typedef enum logic [2:0] {
    IDLE         = 3'd0,
    LOAD_Q       = 3'd1,
    LOAD_K_SCORE = 3'd2,
    LOAD_V       = 3'd3,
    DONE_ST      = 3'd4
  } state_t;

  state_t state;

  logic [5:0] col;  // 0..D_MAX+1
  logic [3:0] row;

  logic signed [DATA_WIDTH-1:0] q_reg [0:D_MAX-1];
  logic signed [ACC_WIDTH-1:0]  max_score;
  logic [3:0]                   max_idx;

  // MAC instance
  logic                         mac_clear, mac_valid;
  logic signed [DATA_WIDTH-1:0] mac_q_in, mac_k_in;
  logic signed [ACC_WIDTH-1:0]  mac_acc;

  mac_unit #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_mac (
    .clk      (clk),
    .rst_n    (rst_n),
    .clear    (mac_clear),
    .valid_in (mac_valid),
    .q_in     (mac_q_in),
    .k_in     (mac_k_in),
    .acc_out  (mac_acc)
  );

  // Current score beats running max?
  logic score_better;
  assign score_better = (row == 4'd0) || (mac_acc > max_score);

  // Combinational SRAM and MAC control
  always_comb begin
    q_re      = 1'b0;
    q_addr    = 5'd0;
    k_re      = 1'b0;
    k_addr    = 9'd0;
    v_re      = 1'b0;
    v_addr    = 9'd0;
    mac_clear = 1'b0;
    mac_valid = 1'b0;
    mac_q_in  = {DATA_WIDTH{1'b0}};
    mac_k_in  = {DATA_WIDTH{1'b0}};

    case (state)
      LOAD_Q: begin
        if (col < 6'(d_val)) begin
          q_re   = 1'b1;
          q_addr = 5'(col);
        end
      end

      LOAD_K_SCORE: begin
        if (col == 6'd0) begin
          k_re      = 1'b1;
          k_addr    = 9'(row) * 9'(D_MAX);
          mac_clear = 1'b1;
        end else if (col <= 6'(d_val)) begin
          if (col < 6'(d_val)) begin
            k_re   = 1'b1;
            k_addr = 9'(row) * 9'(D_MAX) + 9'(col);
          end
          mac_valid = 1'b1;
          mac_q_in  = q_reg[col - 6'd1];
          mac_k_in  = k_rdata;
        end
      end

      LOAD_V: begin
        if (col < 6'(d_val)) begin
          v_re   = 1'b1;
          v_addr = 9'(row) * 9'(D_MAX) + 9'(col);
        end
      end

      default: ;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
      state      <= IDLE;
      col        <= 6'd0;
      row        <= 4'd0;
      max_score  <= {ACC_WIDTH{1'b0}};
      max_idx    <= 4'd0;
      result_idx <= 4'd0;
      done       <= 1'b0;
      busy       <= 1'b0;
      for (i = 0; i < D_MAX; i = i + 1) begin
        q_reg[i]      <= {DATA_WIDTH{1'b0}};
        result_out[i] <= {DATA_WIDTH{1'b0}};
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_Q;
            col   <= 6'd0;
            row   <= 4'd0;
            busy  <= 1'b1;
          end
        end

        LOAD_Q: begin
          if (col > 6'd0) begin
            q_reg[col - 6'd1] <= q_rdata;
          end
          if (col == 6'(d_val)) begin
            state     <= LOAD_K_SCORE;
            col       <= 6'd0;
            row       <= 4'd0;
            max_score <= {1'b1, {(ACC_WIDTH-1){1'b0}}};  // minimum signed value
            max_idx   <= 4'd0;
          end else begin
            col <= col + 6'd1;
          end
        end

        LOAD_K_SCORE: begin
          if (col == 6'(d_val) + 6'd1) begin
            // mac_acc now holds the full dot product
            if (score_better) begin
              max_score <= mac_acc;
              max_idx   <= row;
            end

            if (row == 4'(n_val) - 4'd1) begin
              // Last row: transition to LOAD_V with winning row index
              row   <= score_better ? row : max_idx;
              state <= LOAD_V;
              col   <= 6'd0;
            end else begin
              row <= row + 4'd1;
              col <= 6'd0;
            end
          end else begin
            col <= col + 6'd1;
          end
        end

        LOAD_V: begin
          if (col > 6'd0) begin
            result_out[col - 6'd1] <= v_rdata;
          end
          if (col == 6'(d_val)) begin
            result_idx <= max_idx;
            state      <= DONE_ST;
          end else begin
            col <= col + 6'd1;
          end
        end

        DONE_ST: begin
          done  <= 1'b1;
          busy  <= 1'b0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule
