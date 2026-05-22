// SIMULATION ONLY - NOT SYNTHESIZABLE
module sram_model #(
  parameter int N_MAX      = 16,
  parameter int D_MAX      = 32,
  parameter int DATA_WIDTH = 8
) (
  input  logic                        clk,

  // Q bank: 1 x D_MAX
  input  logic [4:0]                  q_addr,
  input  logic                        q_re,
  output logic signed [DATA_WIDTH-1:0] q_rdata,
  input  logic                        q_we,
  input  logic signed [DATA_WIDTH-1:0] q_wdata,

  // K bank: N_MAX x D_MAX
  input  logic [8:0]                  k_addr,
  input  logic                        k_re,
  output logic signed [DATA_WIDTH-1:0] k_rdata,
  input  logic                        k_we,
  input  logic signed [DATA_WIDTH-1:0] k_wdata,

  // V bank: N_MAX x D_MAX
  input  logic [8:0]                  v_addr,
  input  logic                        v_re,
  output logic signed [DATA_WIDTH-1:0] v_rdata,
  input  logic                        v_we,
  input  logic signed [DATA_WIDTH-1:0] v_wdata,

  // Aggregate access strobes for counter_block
  output logic                        sram_re,
  output logic                        sram_we
);
  logic signed [DATA_WIDTH-1:0] q_mem [0:D_MAX-1];
  logic signed [DATA_WIDTH-1:0] k_mem [0:N_MAX*D_MAX-1];
  logic signed [DATA_WIDTH-1:0] v_mem [0:N_MAX*D_MAX-1];

  assign sram_re = q_re | k_re | v_re;
  assign sram_we = q_we | k_we | v_we;

  always_ff @(posedge clk) begin
    if (q_we) q_mem[q_addr] <= q_wdata;
    if (k_we) k_mem[k_addr] <= k_wdata;
    if (v_we) v_mem[v_addr] <= v_wdata;
  end

  always_ff @(posedge clk) begin
    if (q_re) q_rdata <= q_mem[q_addr];
    if (k_re) k_rdata <= k_mem[k_addr];
    if (v_re) v_rdata <= v_mem[v_addr];
  end

  initial begin
    q_rdata = {DATA_WIDTH{1'b0}};
    k_rdata = {DATA_WIDTH{1'b0}};
    v_rdata = {DATA_WIDTH{1'b0}};
  end
endmodule
