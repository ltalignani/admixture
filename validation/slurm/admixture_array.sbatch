#!/usr/bin/env bash
# One ADMIXTURE run per array task: task i -> K = i/NSEEDS + 1, seed = i%NSEEDS + 1.
# Submitted by slurm/submit.sh, which sets BIN, BED, OUT, THREADS, NSEEDS.
#SBATCH --job-name=admixture
#SBATCH --output=%x_%A_%a.slurm.log
#SBATCH --mem=4G
#SBATCH --time=04:00:00
set -euo pipefail
: "${BIN:?}" "${BED:?}" "${OUT:?}" "${THREADS:?}" "${NSEEDS:=5}"
# non-interactive shells may lack the "module" function
set +u; type module >/dev/null 2>&1 || for f in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /etc/profile.d/lmod.sh; do [ -f "$f" ] && { . "$f"; break; }; done; set -u
if [ -n "${MODULES:-}" ]; then set +u; module load $MODULES; set -u; fi
i=$SLURM_ARRAY_TASK_ID
K=$(( i / NSEEDS + 1 )); s=$(( i % NSEEDS + 1 ))
d="$OUT/K$K/s$s"; mkdir -p "$d"; cd "$d"
[ -s done ] && { echo "K=$K seed=$s already done"; exit 0; }
echo "K=$K seed=$s on $(hostname), $THREADS threads"
start=$(date +%s)
"$BIN" -s "$s" -j"$THREADS" --cv "$BED" "$K" > run.log 2>&1
echo $(( $(date +%s) - start )) > done
