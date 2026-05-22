module accel_top (
  input  logic        clk,
  input  logic        rst_n,

  // CPU interface (OBI)
  input  logic        obi_req,
  output logic        obi_gnt,
  input  logic [31:0] obi_addr,
  input  logic        obi_we,
  input  logic [31:0] obi_wdata,
  output logic [31:0] obi_rdata,
  output logic        obi_rvalid,

  // Status
  output logic        accel_done,
  output logic        accel_busy
);

  localparam int N_MAX      = 16;
  localparam int D_MAX      = 32;
  localparam int DATA_WIDTH = 8;
  localparam int ACC_WIDTH  = 32;

  // Control / status
  logic start_w, done_w, busy_w;
  logic [3:0] n_val_w;
  logic [4:0] d_val_w;

  // Result
  logic [3:0]                   result_idx_w;
  logic signed [DATA_WIDTH-1:0] result_out_w [0:D_MAX-1];

  // Counters
  logic [31:0] cycle_count_w;
  logic [15:0] sram_read_count_w, sram_write_count_w;

  // SRAM write ports (from reg_bank)
  logic [4:0]                   rb_q_addr; logic rb_q_we;
  logic signed [DATA_WIDTH-1:0] rb_q_wdata;
  logic [8:0]                   rb_k_addr; logic rb_k_we;
  logic signed [DATA_WIDTH-1:0] rb_k_wdata;
  logic [8:0]                   rb_v_addr; logic rb_v_we;
  logic signed [DATA_WIDTH-1:0] rb_v_wdata;

  // SRAM read ports (from attention_core)
  logic [4:0] ac_q_addr; logic ac_q_re;
  logic [8:0] ac_k_addr; logic ac_k_re;
  logic [8:0] ac_v_addr; logic ac_v_re;

  // SRAM data outputs
  logic signed [DATA_WIDTH-1:0] q_rdata_w, k_rdata_w, v_rdata_w;

  // SRAM aggregate strobes
  logic sram_re_w, sram_we_w;

  assign accel_done = done_w;
  assign accel_busy = busy_w;

  reg_bank #(
    .N_MAX(N_MAX), .D_MAX(D_MAX), .DATA_WIDTH(DATA_WIDTH)
  ) u_reg_bank (
    .clk                (clk),
    .rst_n              (rst_n),
    .obi_req            (obi_req),
    .obi_gnt            (obi_gnt),
    .obi_addr           (obi_addr),
    .obi_we             (obi_we),
    .obi_wdata          (obi_wdata),
    .obi_rdata          (obi_rdata),
    .obi_rvalid         (obi_rvalid),
    .start_o            (start_w),
    .done_i             (done_w),
    .busy_i             (busy_w),
    .n_val_o            (n_val_w),
    .d_val_o            (d_val_w),
    .result_idx_i       (result_idx_w),
    .result_out_i       (result_out_w),
    .cycle_count_i      (cycle_count_w),
    .sram_read_count_i  (sram_read_count_w),
    .sram_write_count_i (sram_write_count_w),
    .q_addr_o           (rb_q_addr),
    .q_we_o             (rb_q_we),
    .q_wdata_o          (rb_q_wdata),
    .k_addr_o           (rb_k_addr),
    .k_we_o             (rb_k_we),
    .k_wdata_o          (rb_k_wdata),
    .v_addr_o           (rb_v_addr),
    .v_we_o             (rb_v_we),
    .v_wdata_o          (rb_v_wdata)
  );

  attention_core #(
    .N_MAX(N_MAX), .D_MAX(D_MAX),
    .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)
  ) u_attention_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start_w),
    .n_val      (n_val_w),
    .d_val      (d_val_w),
    .q_addr     (ac_q_addr),
    .q_re       (ac_q_re),
    .q_rdata    (q_rdata_w),
    .k_addr     (ac_k_addr),
    .k_re       (ac_k_re),
    .k_rdata    (k_rdata_w),
    .v_addr     (ac_v_addr),
    .v_re       (ac_v_re),
    .v_rdata    (v_rdata_w),
    .result_idx (result_idx_w),
    .result_out (result_out_w),
    .done       (done_w),
    .busy       (busy_w)
  );

  // SRAM: write from reg_bank, read from attention_core (no conflict by protocol)
  sram_model #(
    .N_MAX(N_MAX), .D_MAX(D_MAX), .DATA_WIDTH(DATA_WIDTH)
  ) u_sram (
    .clk     (clk),
    .q_addr  (ac_q_re ? ac_q_addr : rb_q_addr),
    .q_re    (ac_q_re),
    .q_rdata (q_rdata_w),
    .q_we    (rb_q_we),
    .q_wdata (rb_q_wdata),
    .k_addr  (ac_k_re ? ac_k_addr : rb_k_addr),
    .k_re    (ac_k_re),
    .k_rdata (k_rdata_w),
    .k_we    (rb_k_we),
    .k_wdata (rb_k_wdata),
    .v_addr  (ac_v_re ? ac_v_addr : rb_v_addr),
    .v_re    (ac_v_re),
    .v_rdata (v_rdata_w),
    .v_we    (rb_v_we),
    .v_wdata (rb_v_wdata),
    .sram_re (sram_re_w),
    .sram_we (sram_we_w)
  );

  counter_block u_counter (
    .clk              (clk),
    .rst_n            (rst_n),
    .start            (start_w),
    .done             (done_w),
    .sram_re          (sram_re_w),
    .sram_we          (sram_we_w),
    .cycle_count      (cycle_count_w),
    .sram_read_count  (sram_read_count_w),
    .sram_write_count (sram_write_count_w)
  );

endmodule
