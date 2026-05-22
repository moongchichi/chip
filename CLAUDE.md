# Argmax Attention Accelerator — Project Guide

## Architecture

Argmax-only attention accelerator (no softmax, no multi-head):

```
score_i = dot(Q, K_i)   ← int8×int8 → int32 accumulator
idx     = argmax(score_i)
out     = V[idx]
```

Parameters: N_MAX=16, D_MAX=32, DATA_WIDTH=8, ACC_WIDTH=32

### Module Hierarchy

```
accel_top (OBI slave)
├── reg_bank      ← OBI decode, control/status registers, SRAM write path
├── attention_core ← FSM + MAC + SRAM read orchestration
│   └── mac_unit  ← signed int8 × int8 → int32 accumulator
├── sram_model    ← 3-bank simulation SRAM (Q/K/V), NOT synthesizable
└── counter_block ← cycle_count, sram_read_count, sram_write_count
```

### FSM (attention_core)
`IDLE → LOAD_Q → LOAD_K_SCORE → LOAD_V → DONE → IDLE`

- LOAD_Q: reads Q[0..D-1] from SRAM into q_reg[]
- LOAD_K_SCORE: for each row i, MAC dot(Q,K[i]), running argmax
- LOAD_V: reads V[max_idx] into result_out[]
- DONE: pulses done=1 for 1 cycle

### Register Map (OBI byte addresses)
| Addr       | Name       | R/W | Description                    |
|------------|------------|-----|--------------------------------|
| 0x000      | CTRL       | W   | [0]=start (1-cycle pulse)      |
| 0x004      | STATUS     | R   | [0]=done_latch, [1]=busy       |
| 0x008      | IDX_OUT    | R   | [3:0]=result index             |
| 0x010      | N_CFG      | R/W | [3:0]=actual N (default 16)    |
| 0x014      | D_CFG      | R/W | [4:0]=actual D (default 32)    |
| 0x018      | CYCLE_CNT  | R   | cycle_count[31:0]              |
| 0x01C      | SRAM_RD    | R   | sram_read_count[15:0]          |
| 0x020      | SRAM_WR    | R   | sram_write_count[15:0]         |
| 0x030+i×4  | RESULT[i]  | R   | i=0..31, sign-extended int8    |
| 0x100+i×4  | Q_WRITE[i] | W   | i=0..31, load Q byte           |
| 0x200+i×4  | K_WRITE[i] | W   | i=0..511, load K byte          |
| 0xA00+i×4  | V_WRITE[i] | W   | i=0..511, load V byte          |

## RTL Rules

- synthesizable SystemVerilog only (except `sram_model.sv`)
- active-low reset `rst_n` everywhere
- no unsized constants — use `8'd0`, never bare `0`
- no implicit latches — all `always_comb` paths have defaults
- port interface of `accel_top` is frozen — never change without explicit approval

## Verification Rules

- after any RTL change → run `scripts/run_verilator.sh`
- all tests compare against `model/golden_attention.py`
- regression results go to `results/csv/regression_summary.csv`
- log must include: PASS/FAIL, cycle_count, sram_read_count, sram_write_count

## Agent Boundaries

| Agent              | Can modify          |
|--------------------|---------------------|
| architect-agent    | spec/               |
| rtl-agent          | rtl/                |
| verification-agent | tb/ model/ tests/ scripts/ |
| review-agent       | read-only           |

## Milestone Status

- [x] M1 — Argmax attention standalone (single clock, no Ibex)
- [ ] M2 — Register bank + memory-mapped control
- [ ] M3 — Pseudo CPU driver test
- [ ] M4 — Top-k / approximate softmax
- [ ] M5 — Multi-head
- [ ] M6 — Quantized projection
- [ ] M7 — Transformer block
- [ ] M8 — Ibex integration + AXI4-Lite
- [ ] M9 — gem5 model
- [ ] M10 — Synthesis cleanup

## Quick Start

```bash
# Build
bash scripts/run_verilator.sh

# Single test
obj_dir/Vaccel_top_sim --N 16 --D 32 --seed 42

# Regression
python3 scripts/run_regression.py
```
