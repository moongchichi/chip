# Hardware Specification (frozen)

## Algorithm

```
Inputs:
  Q : 1 × D  (int8)
  K : N × D  (int8)
  V : N × D  (int8)

Compute:
  score_i = dot(Q, K_i)    ← int32 accumulator (signed)
  idx     = argmax(score_i) ← first occurrence on tie
  out     = V[idx]          ← 1 × D int8

Parameters (fixed for M1):
  N_MAX      = 16
  D_MAX      = 32
  DATA_WIDTH = 8   (input)
  ACC_WIDTH  = 32  (accumulator)
```

## Top-Level Port (frozen — never change)

```systemverilog
module accel_top (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        obi_req,
  output logic        obi_gnt,
  input  logic [31:0] obi_addr,
  input  logic        obi_we,
  input  logic [31:0] obi_wdata,
  output logic [31:0] obi_rdata,
  output logic        obi_rvalid,
  output logic        accel_done,
  output logic        accel_busy
);
```

## Bus Strategy

- M1–M7: OBI (simple handshake, single clock)
- M8+: AXI4-Lite wrapper added; CDC via 2-flop sync + async FIFO

## Clock Strategy

- M1–M7: single clock (clk + rst_n)
- M8: CPU clk / Accel clk separated; control → 2-flop synchronizer; data → async FIFO

## Memory Layout

SRAM (simulation model, sram_model.sv):
- Q bank:  1  × 32 bytes =   32 bytes
- K bank: 16  × 32 bytes =  512 bytes
- V bank: 16  × 32 bytes =  512 bytes
- Total: ~1 KB, 3 separate banks in simulation
