#!/usr/bin/env python3
"""Compare bootstrap standard errors (.Q_se) of two programs on the same cases.

    python3 compare_qse.py <boot dir A> <boot dir B> [label A] [label B]

Each boot dir holds one subdirectory per case, named <data>_K<K>, containing
<data>.<K>.Q and <data>.<K>.Q_se (written by slurm/bootstrap.sbatch or by hand).
Columns of B are aligned on A using Q. Bootstrap SEs are random, so we compare
their scale and pattern, not exact values:
  - Q_rmse: agreement of the point estimates;
  - mean SE of each program and median ratio SE_B / SE_A (over entries with SE_A > 1e-4);
  - Pearson correlation of the SE matrices and of log SE;
  - share of entries where the two SEs differ by more than a factor 2.
Needs numpy only.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_runs import align, rmse


def load(d, case, ext):
    data, K = case.rsplit("_K", 1)
    return np.loadtxt(os.path.join(d, case, f"{data}.{K}.{ext}"), ndmin=2)


def main():
    a_dir, b_dir = sys.argv[1], sys.argv[2]
    la = sys.argv[3] if len(sys.argv) > 3 else "A"
    lb = sys.argv[4] if len(sys.argv) > 4 else "B"
    cases = sorted(c for c in os.listdir(a_dir)
                   if os.path.isdir(os.path.join(b_dir, c)) and "_K" in c)
    print(f"Q_se: {la} (A) vs {lb} (B)")
    print(f"{'case':<10} {'Q rmse':>8} {'meanSE A':>9} {'meanSE B':>9} {'med B/A':>8} "
          f"{'r':>6} {'r log':>6} {'>2x':>6}")
    for case in cases:
        qa, qb, sa, sb = (load(a_dir, case, "Q"), load(b_dir, case, "Q"),
                          load(a_dir, case, "Q_se"), load(b_dir, case, "Q_se"))
        perm = align(qa, qb)
        qb, sb = qb[:, perm], sb[:, perm]
        keep = sa > 1e-4
        ratio = sb[keep] / sa[keep]
        r = np.corrcoef(sa.ravel(), sb.ravel())[0, 1]
        rlog = np.corrcoef(np.log(sa[keep]), np.log(np.maximum(sb[keep], 1e-9)))[0, 1]
        off2 = float(np.mean((ratio > 2) | (ratio < 0.5)))
        print(f"{case:<10} {rmse(qa, qb):>8.5f} {sa.mean():>9.5f} {sb.mean():>9.5f} "
              f"{np.median(ratio):>8.3f} {r:>6.3f} {rlog:>6.3f} {off2:>6.1%}")


if __name__ == "__main__":
    main()
