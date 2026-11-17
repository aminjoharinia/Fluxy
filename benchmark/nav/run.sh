#!/usr/bin/env bash
# Builds the navigation benchmark in release for this checkout and for a
# git ref (default v1.0.0, from a temporary worktree), runs them alternately
# RUNS times each and prints the lowest median per scenario.
#   benchmark/nav/run.sh            # against v1.0.0, 4 runs each
#   RUNS=2 benchmark/nav/run.sh v1.2.0
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"
ROOT="$(cd ../.. && pwd)"
REF="${1:-v1.0.0}"
RUNS="${RUNS:-4}"
TMP="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$TMP/old" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

git -C "$ROOT" worktree add --detach "$TMP/old" "$REF" >/dev/null
mkdir -p "$TMP/old/benchmark/nav"
rsync -a --exclude build --exclude .dart_tool "$HERE/" "$TMP/old/benchmark/nav/"
# Before v1.2.0 the matcher and the stack had other names.
if ! grep -rq "RouteTable get routeTable" "$TMP/old/packages/fluxy_nav/lib"; then
  cp "$HERE/lib/adapter_v1_0.dart.txt" "$TMP/old/benchmark/nav/lib/adapter.dart"
fi

build() { (cd "$1" && flutter pub get >/dev/null && flutter build macos --release --dart-define=BENCH_OUT="$2" >/dev/null); }
build "$HERE" "$TMP/new.json"
build "$TMP/old/benchmark/nav" "$TMP/old.json"
bin=build/macos/Build/Products/Release/bench_nav.app/Contents/MacOS/bench_nav

for n in $(seq 1 "$RUNS"); do
  "$TMP/old/benchmark/nav/$bin" >/dev/null 2>&1 && mv "$TMP/old.json" "$TMP/old-$n.json"
  "$HERE/$bin" >/dev/null 2>&1 && mv "$TMP/new.json" "$TMP/new-$n.json"
done

python3 - "$TMP" "$REF" <<'PY'
import glob, json, sys
tmp, ref = sys.argv[1], sys.argv[2]
def best(prefix):
    out = {}
    for f in glob.glob(f'{tmp}/{prefix}-*.json'):
        for r in json.load(open(f))['results']:
            out[r['scenario']] = min(out.get(r['scenario'], 1e18), r['usPerOp'])
    return out
old, new = best('old'), best('new')
print(f'| Scenario | {ref} | this checkout | speed-up |')
print('|---|---|---|---|')
for k in old:
    print(f'| {k} | {old[k]:.2f} µs | {new[k]:.2f} µs | {old[k] / new[k]:.2f}× |')
PY
