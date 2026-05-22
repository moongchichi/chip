# Architecture Notes

## Block Diagram

```
CPU (OBI master)
      │ OBI (req/gnt/addr/we/wdata/rdata/rvalid)
      ▼
┌──────────────────────────────────────────────┐
│                  accel_top                   │
│                                              │
│  ┌──────────────┐   start/done/busy/n/d     │
│  │   reg_bank   │──────────────────────────┐│
│  │  (OBI slave) │   SRAM write ports       ││
│  └──────────────┘───────────────┐          ││
│                                 │          ││
│  ┌──────────────────────────┐   │          ││
│  │     attention_core       │   │          ││
│  │  ┌──────────┐            │   │          ││
│  │  │ mac_unit │            │   │          ││
│  │  └──────────┘            │   │          ││
│  │  FSM: IDLE→LOAD_Q→       │   │          ││
│  │       LOAD_K_SCORE→      │   │          ││
│  │       LOAD_V→DONE        │   │          ││
│  └──────────────────────────┘   │          ││
│         │ read ports            │          ││
│         ▼                       ▼          ││
│  ┌──────────────────────────────────┐      ││
│  │           sram_model             │      ││
│  │   Q bank (32B)  K bank (512B)    │      ││
│  │   V bank (512B)                  │      ││
│  └──────────────────────────────────┘      ││
│                    │ sram_re/sram_we        ││
│  ┌─────────────────▼──────────────────┐    ││
│  │          counter_block             │◄───┘│
│  │  cycle_count / sram_rd / sram_wr   │     │
│  └────────────────────────────────────┘     │
└──────────────────────────────────────────────┘
```

## Key Timing (N=16, D=32, 1-cycle SRAM latency)

| Phase         | Cycles        |
|---------------|---------------|
| LOAD_Q        | D + 2 = 34    |
| LOAD_K_SCORE  | N×(D+2) = 544 |
| LOAD_V        | D + 1 = 33    |
| DONE          | 1             |
| **Total**     | **≈ 612**     |

## Design Choices

- **No pipelining in M1**: simplest FSM for correctness verification
- **SRAM 1-cycle latency**: simplest model; synthesis will use BRAM primitives
- **done is a 1-cycle pulse**: reg_bank latches it until STATUS is read
- **OBI gnt is combinational**: always accepts immediately (gnt = req)
- **Signed comparisons**: scores are int32 signed; argmax uses signed `>`
