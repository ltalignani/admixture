#!/usr/bin/env bash
# A/B test of the CV segfault with the real CLI on sim.bed K=4 (the setting of the
# stress-test crash, seed 2109). The arms differ only in Julia's thread option:
#   E: -t 14    (what bin/openadmixture does: 14 threads + 1 interactive thread)
#   F: -t 14,0  (no interactive thread)
#   ./arm.sh <E|F> <first seed>        stop with: touch STOP (current run finishes)
# <arm>.tsv: seed, exit code, seconds, start. Crashed runs keep their folder in crashes/.
set -u
here=$(cd "$(dirname "$0")" && pwd); data=$(cd "$here/../../data" && pwd)
arm=$1; seed=$2
case $arm in E) topt="14" ;; F) topt="14,0" ;; *) echo "arm must be E or F"; exit 1 ;; esac
log="$here/$arm.tsv"; [ -s "$log" ] || printf "seed\texit\tseconds\tstart\n" > "$log"
mkdir -p "$here/crashes"
while [ ! -e "$here/STOP" ]; do
  d="$here/work_$arm"; mkdir -p "$d"; cd "$d" || exit 1
  start=$(date '+%F %T'); SECONDS=0
  julia --project=/Users/loic/OpenADMIXTURE.jl --startup-file=no -t $topt \
    -e 'using OpenADMIXTURE; exit(OpenADMIXTURE.main(ARGS))' -- \
    -s $seed -j14 --cv "$data/sim.bed" 4 > run.log 2>&1; rc=$?
  printf "%s\t%s\t%s\t%s\n" $seed $rc $SECONDS "$start" >> "$log"
  if [ $rc -ne 0 ]; then
    mv "$d" "$here/crashes/${arm}_s${seed}_$(date +%s)"
  else
    rm -f "$d"/*.Q "$d"/*.P "$d/run.log"
  fi
  seed=$((seed + 1))
done
