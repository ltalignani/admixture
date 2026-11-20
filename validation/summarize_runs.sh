#!/usr/bin/env bash
# Collect K, seed, log-likelihood, CV error and run time from <runs dir>/K*/s*/run.log
# into <runs dir>/summary.tsv.   ./summarize_runs.sh <runs dir> [KMAX=8] [SEEDS="1 2 3 4 5"]
set -u   # no -e: missing runs must not stop the table
out=$1; kmax=${2:-8}; seeds=${3:-"1 2 3 4 5"}
{
  printf "K\tseed\tloglikelihood\tcv_error\tseconds\n"
  for K in $(seq 1 "$kmax"); do for s in $seeds; do
    d="$out/K$K/s$s"
    ll=$(grep -E "^Loglikelihood:" "$d/run.log" 2>/dev/null | tail -1 | awk '{print $2}')
    cv=$(grep -oE "CV error \(K=[0-9]+\): *[0-9.eE+-]+" "$d/run.log" 2>/dev/null | awk '{print $NF}')
    printf "%s\t%s\t%s\t%s\t%s\n" "$K" "$s" "$ll" "$cv" "$(cat "$d/done" 2>/dev/null)"
  done; done
} > "$out/summary.tsv"
missing=$(awk -F'\t' 'NR>1 && $5=="" {n++} END {print n+0}' "$out/summary.tsv")
echo "wrote $out/summary.tsv ($missing run(s) missing or failed)"
