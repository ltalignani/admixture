#!/usr/bin/env bash
# Submit K = 1..KMAX x seeds 1..5 (all with --cv) as a Slurm job array, then a
# summary job that writes <output dir>/summary.tsv once every task has ended.
#   slurm/submit.sh <binary> <data.bed> <output dir> [KMAX=8] [THREADS=4] [PARTITION=normal]
# Environment: MODULES="bioinfo-itrop admixture/1.3.0" loads modules in each task (default: none);
#              MAXPAR=20 caps simultaneous tasks; extra sbatch options go in SBATCH_EXTRA.
# Example (iTrop):
#   cd /scratch-ib/admixture-tests
#   MODULES="bioinfo-itrop admixture/1.3.0" slurm/submit.sh admixture data/eur.bed runs/admixture_x86_eur
# On iTrop, /scratch-ib is mounted only on the "normal" and "supermem" nodes: keep PARTITION=normal.
# Re-submitting skips the runs that already have a "done" file.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
bin=$1; bed=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
mkdir -p "$3"; out=$(cd "$3" && pwd)
kmax=${4:-8}; threads=${5:-4}; part=${6:-normal}
nseeds=5; maxpar=${MAXPAR:-20}
[ -f "$bed" ] || { echo "no such file: $bed" >&2; exit 1; }
# resolve the binary now (after loading modules) so every task uses the same one
# non-interactive shells may lack the "module" function
set +u; type module >/dev/null 2>&1 || for f in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /etc/profile.d/lmod.sh; do [ -f "$f" ] && { . "$f"; break; }; done; set -u
if [ -n "${MODULES:-}" ]; then set +u; module load $MODULES; set -u; fi
[ -x "$bin" ] || bin=$(command -v "$bin") || { echo "binary not found: $1" >&2; exit 1; }
last=$(( kmax * nseeds - 1 ))
mkdir -p "$out/slurm_logs"
arr=$(sbatch --parsable --partition="$part" --cpus-per-task="$threads" \
  --array="0-$last%$maxpar" --chdir="$out/slurm_logs" ${SBATCH_EXTRA:-} \
  --export=ALL,BIN="$bin",BED="$bed",OUT="$out",THREADS="$threads",NSEEDS="$nseeds",MODULES="${MODULES:-}" \
  "$here/slurm/admixture_array.sbatch")
sum=$(sbatch --parsable --partition="$part" --job-name=admixture_summary \
  --dependency=afterany:"$arr" --chdir="$out/slurm_logs" --output=summary_%j.log \
  --mem=500M --time=00:10:00 \
  --wrap="'$here/summarize_runs.sh' '$out' $kmax")
echo "array job $arr ($((last + 1)) runs, $threads CPUs each, partition $part); summary job $sum"
echo "follow with: squeue -u \$USER ; results in $out/summary.tsv"
