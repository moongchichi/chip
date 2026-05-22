# Register Map

OBI interface, 32-bit words, byte-addressed, stride 4.
Int8 data occupies bits [7:0] of each word.

| Addr (hex)  | Name        | R/W | Bits       | Description                         |
|-------------|-------------|-----|------------|-------------------------------------|
| 0x000       | CTRL        | W   | [0]=start  | Write 1 to trigger; auto-clears     |
| 0x004       | STATUS      | R   | [1:0]      | [0]=done_latch, [1]=busy            |
| 0x008       | IDX_OUT     | R   | [3:0]      | Result index (0..N-1)               |
| 0x010       | N_CFG       | R/W | [3:0]      | Actual N, default=16                |
| 0x014       | D_CFG       | R/W | [4:0]      | Actual D, default=32                |
| 0x018       | CYCLE_CNT   | R   | [31:0]     | Cycles from start to done           |
| 0x01C       | SRAM_RD_CNT | R   | [15:0]     | SRAM read count                     |
| 0x020       | SRAM_WR_CNT | R   | [15:0]     | SRAM write count                    |
| 0x030+i×4   | RESULT[i]   | R   | [7:0]      | out[i], sign-extended, i=0..31      |
| 0x100+i×4   | Q_WRITE[i]  | W   | [7:0]      | Write Q[i] to SRAM, i=0..31        |
| 0x200+i×4   | K_WRITE[i]  | W   | [7:0]      | Write K[i] to SRAM, i=0..511       |
| 0xA00+i×4   | V_WRITE[i]  | W   | [7:0]      | Write V[i] to SRAM, i=0..511       |

## Notes
- done_latch: set on rising edge of done, cleared on STATUS read
- SRAM indices: K[row][col] → i = row×D_MAX + col (stride = D_MAX = 32)
- Writes to SRAM should happen only while STATUS[1]=0 (accel idle)
