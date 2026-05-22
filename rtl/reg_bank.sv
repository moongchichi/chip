// OBI register bank and address decoder for accel_top
//
// Register map (byte addr, 32-bit words, int8 data in [7:0]):
//   0x000       CTRL        [0]=start (write-only pulse)
//   0x004       STATUS      [0]=done_latch, [1]=busy
//   0x008       IDX_OUT     [3:0]=result_idx
//   0x010       N_CFG       [3:0]=n_val  (default N_MAX)
//   0x014       D_CFG       [4:0]=d_val  (default D_MAX)
//   0x018       CYCLE_CNT   cycle_count[31:0]
//   0x01C       SRAM_RD_CNT sram_read_count[15:0]
//   0x020       SRAM_WR_CNT sram_write_count[15:0]
//   0x030+i*4   RESULT[i]   i=0..31, sign-extended to 32b
//   0x100+i*4   Q_WRITE[i]  i=0..31  -> q_we, q_addr=i
//   0x200+i*4   K_WRITE[i]  i=0..511 -> k_we, k_addr=i
//   0xA00+i*4   V_WRITE[i]  i=0..511 -> v_we, v_addr=i
module reg_bank #(
  parameter int N_MAX      = 16,
  parameter int D_MAX      = 32,
  parameter int DATA_WIDTH = 8
) (
  input  logic        clk,
  input  logic        rst_n,

  // OBI slave
  input  logic        obi_req,
  output logic        obi_gnt,
  input  logic [31:0] obi_addr,
  input  logic        obi_we,
  input  logic [31:0] obi_wdata,
  output logic [31:0] obi_rdata,
  output logic        obi_rvalid,

  // Control / status to attention_core
  output logic        start_o,
  input  logic        done_i,
  input  logic        busy_i,
  output logic [3:0]  n_val_o,
  output logic [4:0]  d_val_o,

  // Result from attention_core
  input  logic [3:0]                   result_idx_i,
  input  logic signed [DATA_WIDTH-1:0] result_out_i [0:D_MAX-1],

  // Counters
  input  logic [31:0] cycle_count_i,
  input  logic [15:0] sram_read_count_i,
  input  logic [15:0] sram_write_count_i,

  // SRAM write ports (pass-through during IDLE)
  output logic [4:0]                   q_addr_o,
  output logic                         q_we_o,
  output logic signed [DATA_WIDTH-1:0] q_wdata_o,
  output logic [8:0]                   k_addr_o,
  output logic                         k_we_o,
  output logic signed [DATA_WIDTH-1:0] k_wdata_o,
  output logic [8:0]                   v_addr_o,
  output logic                         v_we_o,
  output logic signed [DATA_WIDTH-1:0] v_wdata_o
);

  // OBI: always grant immediately
  assign obi_gnt = obi_req;

  // Config registers
  logic [3:0] n_cfg;
  logic [4:0] d_cfg;

  // Done latch: holds done until STATUS is read
  logic done_latch;

  // Registered OBI request for response
  logic        req_r;
  logic [31:0] addr_r;

  // Combinational read data
  logic [31:0] read_data;
  logic [4:0]  res_idx_sel;

  assign res_idx_sel = 5'((obi_addr - 32'h030) >> 2);

  always_comb begin
    read_data = 32'd0;
    if (obi_addr == 32'h004)
      read_data = {30'd0, busy_i, done_latch};
    else if (obi_addr == 32'h008)
      read_data = {28'd0, result_idx_i};
    else if (obi_addr == 32'h010)
      read_data = {28'd0, n_cfg};
    else if (obi_addr == 32'h014)
      read_data = {27'd0, d_cfg};
    else if (obi_addr == 32'h018)
      read_data = cycle_count_i;
    else if (obi_addr == 32'h01C)
      read_data = {16'd0, sram_read_count_i};
    else if (obi_addr == 32'h020)
      read_data = {16'd0, sram_write_count_i};
    else if (obi_addr >= 32'h030 && obi_addr < 32'h0B0)
      read_data = {{(32-DATA_WIDTH){result_out_i[res_idx_sel][DATA_WIDTH-1]}},
                   result_out_i[res_idx_sel]};
    else
      read_data = 32'd0;
  end

  // Sequential: config registers, start pulse, done latch, OBI response
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_o    <= 1'b0;
      n_cfg      <= 4'(N_MAX);
      d_cfg      <= 5'(D_MAX);
      done_latch <= 1'b0;
      obi_rvalid <= 1'b0;
      obi_rdata  <= 32'd0;
      req_r      <= 1'b0;
      addr_r     <= 32'd0;
    end else begin
      start_o <= 1'b0;  // default: no start pulse

      // Latch done, clear on STATUS read
      if (done_i)
        done_latch <= 1'b1;
      else if (obi_req && !obi_we && obi_addr == 32'h004)
        done_latch <= 1'b0;

      // Handle writes
      if (obi_req && obi_we) begin
        if (obi_addr == 32'h000 && obi_wdata[0])
          start_o <= 1'b1;
        else if (obi_addr == 32'h010)
          n_cfg <= 4'(obi_wdata[3:0]);
        else if (obi_addr == 32'h014)
          d_cfg <= 5'(obi_wdata[4:0]);
      end

      // OBI response (1-cycle latency)
      obi_rvalid <= obi_req;
      if (obi_req && !obi_we)
        obi_rdata <= read_data;
      else
        obi_rdata <= 32'd0;
    end
  end

  assign n_val_o = n_cfg;
  assign d_val_o = d_cfg;

  // SRAM write decode (combinational)
  always_comb begin
    q_we_o    = 1'b0;
    q_addr_o  = 5'd0;
    q_wdata_o = {DATA_WIDTH{1'b0}};
    k_we_o    = 1'b0;
    k_addr_o  = 9'd0;
    k_wdata_o = {DATA_WIDTH{1'b0}};
    v_we_o    = 1'b0;
    v_addr_o  = 9'd0;
    v_wdata_o = {DATA_WIDTH{1'b0}};

    if (obi_req && obi_we) begin
      if (obi_addr >= 32'h100 && obi_addr < 32'h180) begin
        q_we_o    = 1'b1;
        q_addr_o  = 5'((obi_addr - 32'h100) >> 2);
        q_wdata_o = signed'(obi_wdata[DATA_WIDTH-1:0]);
      end else if (obi_addr >= 32'h200 && obi_addr < 32'hA00) begin
        k_we_o    = 1'b1;
        k_addr_o  = 9'((obi_addr - 32'h200) >> 2);
        k_wdata_o = signed'(obi_wdata[DATA_WIDTH-1:0]);
      end else if (obi_addr >= 32'hA00 && obi_addr < 32'h1200) begin
        v_we_o    = 1'b1;
        v_addr_o  = 9'((obi_addr - 32'hA00) >> 2);
        v_wdata_o = signed'(obi_wdata[DATA_WIDTH-1:0]);
      end
    end
  end
endmodule
