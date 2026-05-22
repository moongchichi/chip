module mac_unit #(
  parameter int DATA_WIDTH = 8,
  parameter int ACC_WIDTH  = 32
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         clear,
  input  logic                         valid_in,
  input  logic signed [DATA_WIDTH-1:0] q_in,
  input  logic signed [DATA_WIDTH-1:0] k_in,
  output logic signed [ACC_WIDTH-1:0]  acc_out
);
  logic signed [2*DATA_WIDTH-1:0] product;
  assign product = q_in * k_in;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)        acc_out <= {ACC_WIDTH{1'b0}};
    else if (clear)    acc_out <= {ACC_WIDTH{1'b0}};
    else if (valid_in) acc_out <= acc_out + ACC_WIDTH'(product);
  end
endmodule
