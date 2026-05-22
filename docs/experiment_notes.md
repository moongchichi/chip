# Experiment Notes

## M1 Initial Implementation

### Design Decisions
- SRAM uses 1-cycle registered read (matches BRAM behavior on FPGAs)
- MAC clear asserted at col=0 of each LOAD_K_SCORE row
- Comparison at col=d_val+1 after last MAC accumulation completes
- Running argmax: no separate ARGMAX state (merged into LOAD_K_SCORE)

### Known Limitations (M1)
- N and D must be ≤ N_MAX/D_MAX; no bounds checking in RTL
- SRAM writes and reads assumed non-overlapping (CPU loads before start)
- No ECC or parity on SRAM

### TODO for M2
- Add done_latch clear-on-read (already in reg_bank)
- Verify OBI rvalid timing with CPU model
- Add interrupt output pin (optional)
