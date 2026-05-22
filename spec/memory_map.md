# Memory Map

## SRAM Layout (simulation model)

Three independent banks, all synchronous with 1-cycle read latency.

| Bank | Entries        | Size    | Index formula              |
|------|----------------|---------|----------------------------|
| Q    | 1 × D_MAX = 32 | 32 B    | addr = col (0..31)         |
| K    | N_MAX × D_MAX  | 512 B   | addr = row×D_MAX + col     |
| V    | N_MAX × D_MAX  | 512 B   | addr = row×D_MAX + col     |

## OBI Address Space

| Range           | Size   | Function           |
|-----------------|--------|--------------------|
| 0x0000–0x00FF   | 256 B  | Control/status regs |
| 0x0100–0x017F   | 128 B  | Q load (32 entries × 4B) |
| 0x0200–0x09FF   | 2 KB   | K load (512 entries × 4B) |
| 0x0A00–0x11FF   | 2 KB   | V load (512 entries × 4B) |
