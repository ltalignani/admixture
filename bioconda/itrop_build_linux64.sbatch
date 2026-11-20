#!/usr/bin/env bash
#SBATCH --job-name=oa-conda-linux64
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=03:00:00
#SBATCH --output=/scratch-ib/admixture-tests/bioconda/build_linux64_%j.log
# Build and test the openadmixture conda recipe for linux-64 on iTrop.
# Everything lives in /scratch-ib (the /home quota is full).
#   sbatch itrop_build_linux64.sbatch
set -euo pipefail
W=/scratch-ib/admixture-tests/bioconda
cd "$W"
export HOME="$W/home"   # keep conda/julia caches and ~/.condarc out of the full /home
mkdir -p "$HOME"
if [ ! -x "$W/miniforge/bin/conda" ]; then
    curl -fsSL -o miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
    bash miniforge.sh -b -p "$W/miniforge"
    "$W/miniforge/bin/conda" install -y -q -n base conda-build
fi
hostname; nproc; date
"$W/miniforge/bin/conda-build" "$W/recipes/openadmixture" -c conda-forge -c bioconda \
    --croot "$W/croot" --output-folder "$W/out" --no-anaconda-upload
date
ls -lh "$W/out/linux-64/"
