#!/usr/bin/env bash
# Stress test for the rare segfault (sim.bed K=6 seed 2, 2026-11-15): run the real
# CLI with --cv over and over, 2 workers x 14 threads like the original crash.
#   ./stress.sh [WORKERS=2] [THREADS=14]      stop with: touch STOP
# results.tsv: worker, dataset, K, seed, exit code, seconds, start time.
# Crashed runs keep their directory in crashes/; successful ones are deleted.
set -u
here=$(cd "$(dirname "$0")" && pwd); data=$(cd "$here/../data" && pwd)
workers=${1:-2}; threads=${2:-14}
configs=("sim 2" "sim 3" "sim 4" "eur 3" "eur 4" "eur_2000snp 6")
mkdir -p "$here/work" "$here/crashes"
[ -s "$here/results.tsv" ] || printf "worker\tdataset\tK\tseed\texit\tseconds\tstart\n" > "$here/results.tsv"
worker() {
  w=$1; n=0
  while [ ! -e "$here/STOP" ]; do
    c=(${configs[$(( (n + w) % ${#configs[@]} ))]}); set=${c[0]}; K=${c[1]}
    seed=$(( 1000 + 1000 * w + n )); n=$((n + 1))
    d="$here/work/w$w"; mkdir -p "$d"; cd "$d" || exit 1
    start=$(date '+%F %T'); SECONDS=0
    openadmixture -s $seed -j$threads --cv "$data/$set.bed" $K > run.log 2>&1; rc=$?
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" $w $set $K $seed $rc $SECONDS "$start" >> "$here/results.tsv"
    if [ $rc -ne 0 ]; then
      mv "$d" "$here/crashes/${set}_K${K}_s${seed}_w${w}_$(date +%s)"
    else
      rm -f "$d"/*.Q "$d"/*.P "$d/run.log"
    fi
  done
}
for w in $(seq 0 $((workers - 1))); do worker $w & done
wait
echo "stopped; $(awk -F'\t' 'NR>1' "$here/results.tsv" | wc -l) runs, $(awk -F'\t' 'NR>1 && $5!=0' "$here/results.tsv" | wc -l) failed"
