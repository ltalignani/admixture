"""Simulate admixed genotypes (Balding-Nichols + Dirichlet Q) and write PLINK .bed/.bim/.fam."""
import sys
import numpy as np

N, M, K, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
rng = np.random.default_rng(1)
fst = 0.1
anc = rng.uniform(0.05, 0.95, M)
a = anc * (1 - fst) / fst
b = (1 - anc) * (1 - fst) / fst
P = np.clip(rng.beta(a[:, None], b[:, None], size=(M, K)), 1e-3, 1 - 1e-3)  # M x K
Q = rng.dirichlet(np.full(K, 0.5), size=N)  # N x K
np.savetxt(out + ".trueQ", Q, fmt="%.6f")

# PLINK bed: SNP-major, 2 bits/genotype, codes 00=hom A1, 10=het, 11=hom A2, 01=missing
nbytes = (N + 3) // 4
code = np.array([0b00, 0b10, 0b11], dtype=np.uint8)  # count of A2 alleles 0,1,2
with open(out + ".bed", "wb") as f:
    f.write(bytes([0x6C, 0x1B, 0x01]))
    chunk = 5000
    for s in range(0, M, chunk):
        e = min(M, s + chunk)
        H = Q @ P[s:e].T  # N x m
        G = rng.binomial(2, H).T.astype(np.uint8)  # m x N
        c = code[G]
        pad = np.zeros((e - s, nbytes * 4), dtype=np.uint8)
        pad[:, :N] = c
        pad = pad.reshape(e - s, nbytes, 4)
        byte = pad[:, :, 0] | (pad[:, :, 1] << 2) | (pad[:, :, 2] << 4) | (pad[:, :, 3] << 6)
        f.write(byte.astype(np.uint8).tobytes())
with open(out + ".bim", "w") as f:
    for j in range(M):
        f.write(f"1\tsnp{j}\t0\t{j + 1}\tA\tG\n")
with open(out + ".fam", "w") as f:
    for i in range(N):
        f.write(f"ind{i}\tind{i}\t0\t0\t0\t-9\n")
