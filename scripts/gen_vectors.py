"""Generate test vectors for regression testing."""
import json
import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from golden_attention import gen_random, run


def gen_corner_cases():
    N, D = 4, 8
    cases = []

    # All-zero Q: all scores = 0, argmax = 0
    Q = np.zeros((1, D), dtype=np.int8)
    K = np.random.default_rng(0).integers(-128, 127, (N, D), dtype=np.int8)
    V = np.random.default_rng(1).integers(-128, 127, (N, D), dtype=np.int8)
    cases.append(("all_zero_q", run(Q, K, V)))

    # All K rows identical: all scores equal, argmax = 0
    Q = np.ones((1, D), dtype=np.int8)
    K = np.ones((N, D), dtype=np.int8)
    V = np.random.default_rng(2).integers(-128, 127, (N, D), dtype=np.int8)
    cases.append(("same_scores", run(Q, K, V)))

    # Max at last row
    Q  = np.ones((1, D), dtype=np.int8)
    K  = np.zeros((N, D), dtype=np.int8)
    K[-1] = np.ones(D, dtype=np.int8) * 100
    V  = np.random.default_rng(3).integers(-128, 127, (N, D), dtype=np.int8)
    cases.append(("max_at_last", run(Q, K, V)))

    # Max at first row
    K2 = np.zeros((N, D), dtype=np.int8)
    K2[0] = np.ones(D, dtype=np.int8) * 100
    cases.append(("max_at_first", run(Q, K2, V)))

    # Single row (N=1)
    Q1 = np.ones((1, D), dtype=np.int8)
    K1 = np.random.default_rng(4).integers(-128, 127, (1, D), dtype=np.int8)
    V1 = np.random.default_rng(5).integers(-128, 127, (1, D), dtype=np.int8)
    cases.append(("single_row", run(Q1, K1, V1)))

    return cases


def main():
    os.makedirs("tests", exist_ok=True)

    # Small test
    Q, K, V = gen_random(4, 8, seed=42)
    with open("tests/test_small.json", "w") as f:
        json.dump(run(Q, K, V), f, indent=2)
    print("Generated tests/test_small.json")

    # Random tests
    for i in range(100):
        Q, K, V = gen_random(16, 32, seed=i)
        with open(f"tests/test_random_{i:03d}.json", "w") as f:
            json.dump(run(Q, K, V), f, indent=2)
    print("Generated tests/test_random_000..099.json")

    # Corner cases
    for name, result in gen_corner_cases():
        with open(f"tests/test_corner_{name}.json", "w") as f:
            json.dump(result, f, indent=2)
        print(f"Generated tests/test_corner_{name}.json")


if __name__ == "__main__":
    main()
