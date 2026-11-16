#!/usr/bin/env bash
# Builds every benchmark app in release (AOT) for macOS and runs it RUNS
# times; results/<lib>-<n>.json, then results/summary.json.
#   benchmark/run.sh            # all libraries, 3 runs each
#   RUNS=1 benchmark/run.sh fluxy riverpod
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
RUNS="${RUNS:-3}"
LIBS=("$@")
if [ ${#LIBS[@]} -eq 0 ]; then LIBS=(fluxy getx5 getx4 riverpod bloc signals); fi
mkdir -p "$ROOT/results"

for lib in "${LIBS[@]}"; do
  echo "== $lib: build"
  (cd "apps/$lib" && flutter pub get >/dev/null &&
    flutter build macos --release \
      --dart-define=BENCH_OUT="$ROOT/results/$lib.json" >/dev/null)
  bin="apps/$lib/build/macos/Build/Products/Release/bench_$lib.app/Contents/MacOS/bench_$lib"
  for n in $(seq 1 "$RUNS"); do
    echo "== $lib: run $n/$RUNS"
    rm -f "$ROOT/results/$lib.json"
    "$bin" >/dev/null 2>&1
    mv "$ROOT/results/$lib.json" "$ROOT/results/$lib-$n.json"
  done
done

python3 "$ROOT/summarize.py" "$ROOT"
