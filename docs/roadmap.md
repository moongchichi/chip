# Roadmap

| MS  | Feature                          | Status  |
|-----|----------------------------------|---------|
| M1  | Argmax attention standalone      | In progress |
| M2  | Register bank + memory-mapped    | Pending |
| M3  | Pseudo CPU driver test           | Pending |
| M4  | Top-k / approximate softmax      | Pending |
| M5  | Multi-head attention             | Pending |
| M6  | Quantized linear projection      | Pending |
| M7  | Transformer block fragment       | Pending |
| M8  | Ibex + OBI + AXI4-Lite + CDC    | Pending |
| M9  | gem5 abstract model              | Pending |
| M10 | Synthesis-ready cleanup          | Pending |

## Progression Rule

Before starting M(n+1):
1. M(n) Verilator regression must be 100% PASS
2. CLAUDE.md milestone table updated
3. Any new spec committed to spec/ directory
