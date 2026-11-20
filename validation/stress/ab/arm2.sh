#!/usr/bin/env bash
# One arm of the A/B test: restart Julia every 10 passes or after a crash.
#   [JFLAGS=...] ./arm2.sh <name> <quiet true|false> <first seed>     stop with: touch STOP
here=$(cd "$(dirname "$0")" && pwd); name=$1; quiet=$2; seed=$3
log="$here/$name.tsv"; [ -s "$log" ] || printf "seed_start\texit\tpasses\tseconds\tend\n" > "$log"
while [ ! -e "$here/STOP" ]; do
  SECONDS=0
  julia -t 14,0 $JFLAGS --project=/Users/loic/OpenADMIXTURE.jl "$here/cv_loop.jl" $quiet $seed 10 \
    > /dev/null 2> "$here/$name.current.err"; rc=$?
  n=$(grep -c '^PASS' "$here/$name.current.err")
  printf "%s\t%s\t%s\t%s\t%s\n" $seed $rc $n $SECONDS "$(date '+%F %T')" >> "$log"
  cat "$here/$name.current.err" >> "$here/$name.err"
  [ $rc -ne 0 ] && cp "$here/$name.current.err" "$here/$name.crash_seed$seed.err"
  seed=$((seed + 10))
done
