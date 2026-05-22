# Algorithm Specification

## Argmax Attention (M1)

### Formula
```
score_i = Σ_j Q[j] × K[i][j]   for i = 0..N-1
idx     = argmax(score_i)        first occurrence on tie
out     = V[idx]
```

### Data Types
| Signal  | Type      | Width  |
|---------|-----------|--------|
| Q[j]    | int8      | 8-bit  |
| K[i][j] | int8      | 8-bit  |
| V[i][j] | int8      | 8-bit  |
| score_i | int32     | 32-bit |
| out[j]  | int8      | 8-bit  |

### Overflow Analysis
Max score = D_MAX × 127 × 127 = 32 × 16129 = 516,128 << 2^31
→ No overflow in int32 accumulator.

### Tie-breaking
argmax returns the **first** index with the maximum score (matching numpy behavior).

### Cycle Budget (M1, N=16, D=32)
- LOAD_Q:       34 cycles (32 reads + 2 overhead)
- LOAD_K_SCORE: 544 cycles (16 rows × 34 cycles)
- LOAD_V:       33 cycles
- DONE:         1 cycle
- **Total ≈ 612 cycles**
