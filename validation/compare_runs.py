#!/usr/bin/env python3
"""Compare two sets of runs (e.g. ADMIXTURE x86 vs OpenADMIXTURE) on one data set.

    python3 compare_runs.py <runs A> <runs B> <data prefix> [true Q file] [label A] [label B]

<runs X> are directories written by run_admixture.sh or slurm/submit.sh
(K*/s*/run.log, prefix.K.Q, prefix.K.P, summary.tsv). For each K, the run with the
best log-likelihood of each program is kept, its clusters are aligned with the
other program's (best permutation of columns), and the script reports:
  - best log-likelihood of each program and the difference B - A;
  - CV error (mean and min over seeds) of each program, and the K each one picks;
  - Q agreement: RMSE and max absolute difference between aligned Q matrices;
  - P agreement: RMSE of aligned P, and whether B's P is A's P or 1 - P
    (allele orientation);
  - with a true Q file (simulations): RMSE of each program's Q at the true K.
Writes a TSV next to the console output: <runs B>/compare_vs_<basename runs A>.tsv
Needs numpy only (the "pong" conda env has it).
"""
import itertools
import os
import sys

import numpy as np


def read_summary(runs):
    rows = {}
    with open(os.path.join(runs, "summary.tsv")) as f:
        next(f)
        for line in f:
            K, seed, ll, cv, sec = (line.rstrip("\n").split("\t") + [""] * 5)[:5]
            if ll == "":
                continue
            rows.setdefault(int(K), []).append(
                (int(seed), float(ll), float(cv) if cv else np.nan, float(sec) if sec else np.nan))
    return rows


def best_run(rows, K):
    return max(rows[K], key=lambda r: r[1])


def load(runs, prefix, K, seed, ext):
    return np.loadtxt(os.path.join(runs, f"K{K}", f"s{seed}", f"{prefix}.{K}.{ext}"), ndmin=2)


def align(ref, x):
    """Column permutation of x that best matches ref (min squared error)."""
    K = ref.shape[1]
    cost = ((ref[:, :, None] - x[:, None, :]) ** 2).sum(axis=0)  # cost[i, j]: ref col i vs x col j
    if K <= 8:
        best = min(itertools.permutations(range(K)), key=lambda p: cost[range(K), p].sum())
        return list(best)
    perm, used = [], set()  # greedy fallback for large K
    for i in range(K):
        j = min((j for j in range(K) if j not in used), key=lambda j: cost[i, j])
        perm.append(j)
        used.add(j)
    return perm


def rmse(a, b):
    return float(np.sqrt(np.mean((a - b) ** 2)))


def main():
    a_dir, b_dir, prefix = sys.argv[1], sys.argv[2], os.path.basename(sys.argv[3]).removesuffix(".bed")
    trueq = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] not in ("", "-") else None
    la = sys.argv[5] if len(sys.argv) > 5 else os.path.basename(os.path.normpath(a_dir))
    lb = sys.argv[6] if len(sys.argv) > 6 else os.path.basename(os.path.normpath(b_dir))
    A, B = read_summary(a_dir), read_summary(b_dir)
    Ks = sorted(set(A) & set(B))
    Qtrue = np.loadtxt(trueq, ndmin=2) if trueq else None
    Ktrue = Qtrue.shape[1] if Qtrue is not None else None

    cols = ["K", f"ll_{la}", f"ll_{lb}", "ll_diff", f"cv_mean_{la}", f"cv_mean_{lb}",
            f"cv_min_{la}", f"cv_min_{lb}", "Q_rmse", "Q_maxabs", "P_rmse", "P_orientation",
            f"Qtrue_rmse_{la}", f"Qtrue_rmse_{lb}", f"sec_mean_{la}", f"sec_mean_{lb}"]
    out = []
    for K in Ks:
        sa, lla, *_ = best_run(A, K)
        sb, llb, *_ = best_run(B, K)
        qa, qb_raw = load(a_dir, prefix, K, sa, "Q"), load(b_dir, prefix, K, sb, "Q")
        pa, pb = load(a_dir, prefix, K, sa, "P"), load(b_dir, prefix, K, sb, "P")
        perm = align(qa, qb_raw)
        qb, pb = qb_raw[:, perm], pb[:, perm]
        same, flipped = rmse(pa, pb), rmse(pa, 1 - pb)
        orient = "same" if same <= flipped else "1-P"
        row = {
            "K": K, f"ll_{la}": lla, f"ll_{lb}": llb, "ll_diff": llb - lla,
            f"cv_mean_{la}": np.nanmean([r[2] for r in A[K]]), f"cv_mean_{lb}": np.nanmean([r[2] for r in B[K]]),
            f"cv_min_{la}": np.nanmin([r[2] for r in A[K]]), f"cv_min_{lb}": np.nanmin([r[2] for r in B[K]]),
            "Q_rmse": rmse(qa, qb), "Q_maxabs": float(np.abs(qa - qb).max()),
            "P_rmse": min(same, flipped), "P_orientation": orient,
            f"Qtrue_rmse_{la}": np.nan, f"Qtrue_rmse_{lb}": np.nan,
            f"sec_mean_{la}": np.nanmean([r[3] for r in A[K]]), f"sec_mean_{lb}": np.nanmean([r[3] for r in B[K]]),
        }
        if Qtrue is not None and K == Ktrue:
            row[f"Qtrue_rmse_{la}"] = rmse(Qtrue, qa[:, align(Qtrue, qa)])
            row[f"Qtrue_rmse_{lb}"] = rmse(Qtrue, qb_raw[:, align(Qtrue, qb_raw)])
        out.append(row)

    path = os.path.join(b_dir, f"compare_vs_{os.path.basename(os.path.normpath(a_dir))}.tsv")
    with open(path, "w") as f:
        f.write("\t".join(cols) + "\n")
        f.writelines("\t".join(f"{r[c]:.6g}" if isinstance(r[c], float) else str(r[c]) for c in cols) + "\n"
                     for r in out)

    print(f"{prefix}: {la} (A) vs {lb} (B)")
    print(f"{'K':>2} {'bestLL A':>16} {'bestLL B':>16} {'B-A':>9} {'CVmean A':>9} {'CVmean B':>9} "
          f"{'Q rmse':>8} {'Q max':>7} {'P rmse':>8} {'P':>5} {'s A':>6} {'s B':>6}")
    for r in out:
        print(f"{r['K']:>2} {r[f'll_{la}']:>16.3f} {r[f'll_{lb}']:>16.3f} {r['ll_diff']:>9.2f} "
              f"{r[f'cv_mean_{la}']:>9.5f} {r[f'cv_mean_{lb}']:>9.5f} {r['Q_rmse']:>8.5f} "
              f"{r['Q_maxabs']:>7.4f} {r['P_rmse']:>8.5f} {r['P_orientation']:>5} "
              f"{r[f'sec_mean_{la}']:>6.0f} {r[f'sec_mean_{lb}']:>6.0f}")
    pick = lambda col: min(out, key=lambda r: r[col])["K"]
    print(f"K with lowest mean CV error: A = {pick(f'cv_mean_{la}')}, B = {pick(f'cv_mean_{lb}')}")
    if Qtrue is not None:
        r = next((r for r in out if r["K"] == Ktrue), None)
        if r:
            print(f"RMSE vs true Q at K={Ktrue}: A = {r[f'Qtrue_rmse_{la}']:.5f}, B = {r[f'Qtrue_rmse_{lb}']:.5f}")
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
