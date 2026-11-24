#!/usr/bin/env bash
# ADMIXTURE bootstrap runs (-B) for the Q_se comparison, one array task per case.
#   sbatch --array=0-2 slurm/bootstrap.sbatch            (from /scratch-ib/admixture-tests)
# Writes runs/admixture_x86_boot/<data>_K<K>/ with <data>.<K>.Q, .P, .Q_se and run.log.
#SBATCH --job-name=admix_boot
#SBATCH --output=%x_%A_%a.slurm.log
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=12:00:00
set -euo pipefail
CASES=("mini 3" "eur 2" "eur 3")
read -r data K <<< "${CASES[$SLURM_ARRAY_TASK_ID]}"
set +u; type module >/dev/null 2>&1 || for f in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /etc/profile.d/lmod.sh; do [ -f "$f" ] && { . "$f"; break; }; done
module load bioinfo-itrop admixture/1.3.0; set -u
base=$(pwd)
d="$base/runs/admixture_x86_boot/${data}_K$K"; mkdir -p "$d"; cd "$d"
echo "$data K=$K on $(hostname)"
start=$(date +%s)
admixture -s 1 -j4 -B200 "$base/data/$data.bed" "$K" > run.log 2>&1
echo $(( $(date +%s) - start )) > done
