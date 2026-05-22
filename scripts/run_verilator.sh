#!/bin/bash
set -e
PROJ=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJ"

if ! command -v verilator &>/dev/null; then
  echo "Verilator not found. Install:"
  echo "  brew install verilator        # macOS"
  echo "  sudo apt-get install verilator # Ubuntu"
  exit 1
fi

echo "=== Verilator build ==="
verilator --cc --exe --build \
  -Wall -Wno-UNUSED -Wno-DECLFILENAME -Wno-UNOPTFLAT \
  rtl/accel_top.sv \
  rtl/reg_bank.sv \
  rtl/attention_core.sv \
  rtl/mac_unit.sv \
  rtl/sram_model.sv \
  rtl/counter_block.sv \
  tb/verilator_main.cpp \
  --top-module accel_top \
  -o obj_dir/Vaccel_top_sim \
  2>&1

echo "=== Build OK ==="
echo "Run: obj_dir/Vaccel_top_sim [--N 16] [--D 32] [--seed 42]"
