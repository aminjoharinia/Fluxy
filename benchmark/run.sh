#!/usr/bin/env bash
# Builds every benchmark app in release (AOT) for macOS and runs it RUNS
# times; results/<lib>-<n>.json, then results/summary.json.
#   benchmark/run.sh            # all libraries, 3 runs each
#   RUNS=1 benchmark/run.sh fluxy riverpod
#   SIZE=heavy benchmark/run.sh  # tiny | normal | heavy | super
# Sizes other than normal write to results/<size>/.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
RUNS="${RUNS:-3}"
SIZE="${SIZE:-normal}"
case "$SIZE" in
  tiny | normal | heavy | super) ;;
  *) echo "SIZE must be tiny, normal, heavy or super" >&2; exit 1 ;;
esac
OUT="$ROOT/results"
if [ "$SIZE" != normal ]; then OUT="$ROOT/results/$SIZE"; fi
LIBS=("$@")
if [ ${#LIBS[@]} -eq 0 ]; then LIBS=(fluxy getx5 getx4 riverpod bloc signals); fi
mkdir -p "$OUT"

for lib in "${LIBS[@]}"; do
  echo "== $lib: build ($SIZE)"
  (cd "apps/$lib" && flutter pub get >/dev/null &&
    flutter build macos --release \
      --dart-define=BENCH_OUT="$OUT/$lib.json" \
      --dart-define=BENCH_SIZE="$SIZE" >/dev/null)
  bin="apps/$lib/build/macos/Build/Products/Release/bench_$lib.app/Contents/MacOS/bench_$lib"
  for n in $(seq 1 "$RUNS"); do
    echo "== $lib: run $n/$RUNS"
    rm -f "$OUT/$lib.json"
    "$bin" >/dev/null 2>&1
    mv "$OUT/$lib.json" "$OUT/$lib-$n.json"
  done
done

python3 "$ROOT/summarize.py" "$ROOT" "$SIZE"
