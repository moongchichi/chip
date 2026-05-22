"""Golden reference model for Argmax Attention Accelerator."""
import numpy as np
import argparse
import json
import sys


def argmax_attention(Q, K, V):
    """
    Q: (1, D) int8
    K: (N, D) int8
    V: (N, D) int8
    Returns: (out, idx, scores)
      out    : (D,) int8  = V[argmax]
      idx    : int        = argmax of dot products
      scores : (N,) int32 = dot(Q, K_i) for each i
    """
    N, D = K.shape
    scores = np.zeros(N, dtype=np.int32)
    for i in range(N):
        scores[i] = np.sum(Q[0].astype(np.int32) * K[i].astype(np.int32))
    idx = int(np.argmax(scores))  # first occurrence on tie
    out = V[idx].copy()
    return out, idx, scores


def gen_random(N, D, seed=0):
    rng = np.random.default_rng(seed)
    Q = rng.integers(-128, 127, (1, D), dtype=np.int8)
    K = rng.integers(-128, 127, (N, D), dtype=np.int8)
    V = rng.integers(-128, 127, (N, D), dtype=np.int8)
    return Q, K, V


def run(Q, K, V):
    out, idx, scores = argmax_attention(Q, K, V)
    return {
        "N": int(K.shape[0]),
        "D": int(K.shape[1]),
        "Q": Q.tolist(),
        "K": K.tolist(),
        "V": V.tolist(),
        "scores": scores.tolist(),
        "idx": idx,
        "out": out.tolist(),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Argmax attention golden model")
    parser.add_argument("--input",  help="Input JSON file")
    parser.add_argument("--output", help="Output JSON file (default: stdout)")
    parser.add_argument("--N", type=int, default=4)
    parser.add_argument("--D", type=int, default=8)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    if args.input:
        with open(args.input) as f:
            data = json.load(f)
        Q = np.array(data["Q"], dtype=np.int8)
        K = np.array(data["K"], dtype=np.int8)
        V = np.array(data["V"], dtype=np.int8)
    else:
        Q, K, V = gen_random(args.N, args.D, args.seed)

    result = run(Q, K, V)
    out_str = json.dumps(result, indent=2)

    if args.output:
        with open(args.output, "w") as f:
            f.write(out_str)
    else:
        print(out_str)
