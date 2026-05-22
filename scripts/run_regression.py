#!/usr/bin/env python3
"""Run regression: 100 random tests + 5 corner cases, save CSV summary."""
import subprocess
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from parse_log import parse_line

SIM = os.path.join(os.path.dirname(__file__), '..', 'obj_dir', 'Vaccel_top_sim')
OUT_CSV = os.path.join(os.path.dirname(__file__), '..', 'results', 'csv', 'regression_summary.csv')


def run_one(seed, N=16, D=32):
    cmd = [SIM, '--N', str(N), '--D', str(D), '--seed', str(seed)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        line = r.stdout.strip().splitlines()[0] if r.stdout.strip() else 'FAIL timeout'
        parsed = parse_line(line)
        parsed['seed'] = seed
        parsed['N'] = N
        parsed['D'] = D
        return parsed
    except subprocess.TimeoutExpired:
        return {'status': 'FAIL', 'raw': 'timeout', 'seed': seed, 'N': N, 'D': D}


def main():
    if not os.path.exists(SIM):
        print(f"Simulator not found: {SIM}")
        print("Run scripts/run_verilator.sh first.")
        sys.exit(1)

    os.makedirs(os.path.dirname(OUT_CSV), exist_ok=True)

    results = []

    # 100 random tests
    print("Running 100 random tests (N=16, D=32)...")
    for seed in range(100):
        r = run_one(seed)
        results.append(r)
        print(f"  seed={seed:3d}: {r['status']}"
              + (f" cycles={r.get('cycles','?')} sram_rd={r.get('sram_rd','?')}" if r['status'] == 'PASS' else ''))

    # Corner cases (smaller N/D)
    print("Running corner cases...")
    corners = [(42, 1, 8), (43, 4, 8), (44, 16, 32), (45, 4, 4), (46, 1, 1)]
    for seed, N, D in corners:
        r = run_one(seed, N, D)
        results.append(r)
        print(f"  N={N} D={D} seed={seed}: {r['status']}")

    # Write CSV
    fields = ['status', 'seed', 'N', 'D', 'idx', 'expected', 'cycles', 'sram_rd', 'sram_wr', 'raw']
    with open(OUT_CSV, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        w.writeheader()
        w.writerows(results)

    passed = sum(1 for r in results if r['status'] == 'PASS')
    total  = len(results)
    print(f"\n=== RESULT: {passed}/{total} PASS ===")
    print(f"Summary saved to {OUT_CSV}")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
