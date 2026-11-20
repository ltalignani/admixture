#!/usr/bin/env bash
# Run ADMIXTURE (x86) or OpenADMIXTURE on one data set for K = 1..KMAX and several seeds,
# with 5-fold cross-validation, in the layout expected by make_pong.sh.
#   ./run_admixture.sh <binary> <data.bed> <output dir> [KMAX=8] [THREADS=4] [PARALLEL=6]
# Example (x86 Linux):  ./run_admixture.sh /path/to/admixture data/eur.bed runs/admixture_x86
# Example (this Mac):   ./run_admixture.sh openadmixture data/eur.bed runs/openadmixture
set -euo pipefail
bin=$1; bed=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); out=$3
kmax=${4:-8}; threads=${5:-4}; par=${6:-6}
seeds="1 2 3 4 5"
mkdir -p "$out"
jobs=()
for K in $(seq 1 "$kmax"); do for s in $seeds; do jobs+=("$K $s"); done; done
printf '%s\n' "${jobs[@]}" | xargs -P "$par" -L 1 bash -c '
  K=$0; s=$1; d="'"$out"'/K$K/s$s"; mkdir -p "$d"; cd "$d"
  [ -s done ] && exit 0
  start=$(date +%s)
  if "'"$bin"'" -s "$s" -j'"$threads"' --cv "'"$bed"'" "$K" > run.log 2>&1; then
    echo $(( $(date +%s) - start )) > done
  else
    echo "FAILED K=$K seed=$s (see $d/run.log)" >&2
  fi'
"$(dirname "$0")/summarize_runs.sh" "$out" "$kmax" "$seeds"
