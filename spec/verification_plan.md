# Verification Plan — M1

## Test Suite

| Suite        | Count | N  | D  | Description                         |
|--------------|-------|----|----|-------------------------------------|
| Random       | 100   | 16 | 32 | Full N_MAX × D_MAX, seeds 0..99     |
| Corner       | 5     | varies | varies | Edge cases (see below)     |
| Smoke        | 1     | 4  | 8  | Quick build verification            |

## Corner Cases

1. **all_zero_q**: Q=0 → all scores=0 → idx must be 0
2. **same_scores**: all K rows identical → scores equal → idx must be 0 (first)
3. **max_at_last**: max score at row N-1
4. **max_at_first**: max score at row 0
5. **single_row**: N=1 → must select idx=0 regardless

## Pass Criteria

For each test:
- `rtl_idx == golden_idx`
- `rtl_out[i] == golden_out[i]` for all i in 0..D-1
- No timeout (< 100,000 cycles)

## Counters (informational, not pass/fail)

| Counter          | Expected (N=16, D=32) |
|------------------|-----------------------|
| cycle_count      | ≈ 612                 |
| sram_read_count  | D + N×D + D = 576     |
| sram_write_count | D + N×D + N×D = 1056  |

## Regression Output

File: `results/csv/regression_summary.csv`
Columns: status, seed, N, D, idx, expected, cycles, sram_rd, sram_wr, raw
