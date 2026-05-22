module counter_block #(
  parameter int CYCLE_WIDTH = 32,
  parameter int COUNT_WIDTH = 16
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      start,
  input  logic                      done,
  input  logic                      sram_re,
  input  logic                      sram_we,
  output logic [CYCLE_WIDTH-1:0]    cycle_count,
  output logic [COUNT_WIDTH-1:0]    sram_read_count,
  output logic [COUNT_WIDTH-1:0]    sram_write_count
);
  logic counting;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counting         <= 1'b0;
      cycle_count      <= {CYCLE_WIDTH{1'b0}};
      sram_read_count  <= {COUNT_WIDTH{1'b0}};
      sram_write_count <= {COUNT_WIDTH{1'b0}};
    end else if (start) begin
      counting         <= 1'b1;
      cycle_count      <= {CYCLE_WIDTH{1'b0}};
      sram_read_count  <= {COUNT_WIDTH{1'b0}};
      sram_write_count <= {COUNT_WIDTH{1'b0}};
    end else if (done) begin
      counting <= 1'b0;
    end else if (counting) begin
      cycle_count <= cycle_count + {{(CYCLE_WIDTH-1){1'b0}}, 1'b1};
      if (sram_re) sram_read_count  <= sram_read_count  + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
      if (sram_we) sram_write_count <= sram_write_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
    end
  end
endmodule
