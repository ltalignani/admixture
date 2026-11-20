#!/usr/bin/env bash
# Align the .Q files of all runs with pong and export the figure.
#   ./make_pong.sh <runs dir> <data prefix> <ind2pop> <pop order> [KMIN=1] [PORT=4000]
# Several runs dirs separated by ":" put all their runs in one pong figure, with the
# clusters aligned across programs (output in runs/pong_compare_<prefix>/), e.g.
#   ./make_pong.sh runs/admixture_x86_eur:runs/openadmixture_eur data/eur.bed data/eur.ind2pop data/eur.pop_order
# Needs the "pong" conda env (conda create -n pong python=3.10 && pip install pong)
# and Google Chrome (to render pong's web page to PNG/PDF).
set -euo pipefail
prefix=$(basename "$2" .bed); ind2pop=$3; popnames=$4
kmin=${5:-1}; port=${6:-4000}
IFS=: read -r -a dirs <<< "$1"
if [ ${#dirs[@]} -eq 1 ]; then out="$(cd "$1" && pwd)/pong"
else out="$(cd "$(dirname "${dirs[0]}")" && pwd)/pong_compare_$prefix"; fi
mkdir -p "$out"
filemap="$out/filemap.txt"; : > "$filemap"
for r in "${dirs[@]}"; do
  runs=$(cd "$r" && pwd)
  tag=""; [ ${#dirs[@]} -gt 1 ] && tag="$(basename "$runs")_"
  for d in "$runs"/K*/s*; do
    K=${d#"$runs"/K}; K=${K%%/*}; s=${d##*/s}
    [ "$K" -ge "$kmin" ] || continue
    q="$d/$prefix.$K.Q"
    [ -s "$q" ] && printf "%sK%s_s%s\t%s\t%s\n" "$tag" "$K" "$s" "$K" "$q" >> "$filemap"
  done
done
sort -t$'\t' -k2,2n -k1,1V "$filemap" -o "$filemap"
PYTHONUNBUFFERED=1 conda run --no-capture-output -n pong pong -m "$filemap" -i "$ind2pop" -n "$popnames" -o "$out/pong_output" -f -g \
    -p "$port" > "$out/pong.log" 2>&1 &
pid=$!
for _ in $(seq 1 120); do
  grep -q "localhost:$port" "$out/pong.log" 2>/dev/null && break
  kill -0 $pid 2>/dev/null || { cat "$out/pong.log"; exit 1; }
  sleep 1
done
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for fmt in png pdf; do
  args=(--headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=30000 --window-size=1600,2000)
  if [ $fmt = png ]; then args+=(--screenshot="$out/pong.png"); else args+=(--print-to-pdf="$out/pong.pdf" --no-pdf-header-footer); fi
  "$chrome" "${args[@]}" "http://localhost:$port/" >/dev/null 2>&1 || true
done
pkill -f "pong -m $filemap" 2>/dev/null || true; kill $pid 2>/dev/null || true
echo "pong results: $out (pong.png, pong.pdf, pong_output/)"
