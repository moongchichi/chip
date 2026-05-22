#!/usr/bin/env python3
"""Plot regression results from CSV summary."""
import csv
import os
import sys

CSV_FILE = os.path.join(os.path.dirname(__file__), '..', 'results', 'csv', 'regression_summary.csv')
FIG_DIR  = os.path.join(os.path.dirname(__file__), '..', 'results', 'figures')

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
except ImportError:
    print("matplotlib not installed. Install with: pip install matplotlib")
    sys.exit(0)


def main():
    if not os.path.exists(CSV_FILE):
        print(f"CSV not found: {CSV_FILE}. Run run_regression.py first.")
        sys.exit(1)

    rows = []
    with open(CSV_FILE) as f:
        rows = list(csv.DictReader(f))

    passed = [r for r in rows if r['status'] == 'PASS']
    failed = [r for r in rows if r['status'] != 'PASS']
    cycles = [int(r['cycles']) for r in passed if r.get('cycles')]

    os.makedirs(FIG_DIR, exist_ok=True)

    # Cycle count histogram
    if cycles:
        fig, ax = plt.subplots()
        ax.hist(cycles, bins=20, color='steelblue', edgecolor='black')
        ax.set_xlabel('Cycle Count')
        ax.set_ylabel('Frequency')
        ax.set_title('Cycle Count Distribution (PASS cases)')
        fig.tight_layout()
        fig.savefig(os.path.join(FIG_DIR, 'cycle_histogram.png'), dpi=150)
        print(f"Saved cycle_histogram.png")

    # Pass/fail pie
    fig, ax = plt.subplots()
    ax.pie([len(passed), len(failed)],
           labels=[f'PASS ({len(passed)})', f'FAIL ({len(failed)})'],
           colors=['green', 'red'], autopct='%1.0f%%')
    ax.set_title('Regression Pass/Fail')
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, 'pass_fail_pie.png'), dpi=150)
    print(f"Saved pass_fail_pie.png")


if __name__ == "__main__":
    main()
