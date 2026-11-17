# Navigation benchmark

Release (AOT) macOS app timing fluxy_nav, compared with an older Fluxy version built from a temporary git worktree. Only API both versions share is used; `lib/adapter.dart` holds the version-specific calls (`adapter_v1_0.dart.txt` for versions before v1.2.0).

| Scenario | One op |
|---|---|
| match | match one address against 152 pages (100 static, 50 `/:id`, a 6-level nested chain): the last static page, a parameter page, the deepest nested page, an unknown address, the first static page |
| push + pop | `Fluxy.toNamed` + one frame, `Fluxy.back` + one frame |
| push 100 deep | `Fluxy.toNamed` + one frame on a growing stack (1 to 100 pages), then `offAllNamed` (counted in) |
| deep link | `Fluxy.offAllNamed` to a nested or parameter page + one frame |
| dialog open + close | `Fluxy.dialog` + frame, `Fluxy.back` + frame |

Pages have no transition, so each frame finishes its route changes. Each scenario: one warm-up, 15 samples, median; the table keeps the lowest median of the runs, which alternate old / new builds.

```bash
benchmark/nav/run.sh          # this checkout against v1.0.0
```

## Results (2026-11-17, v1.2.0 against v1.0.0, 4 runs each, Apple silicon)

| Scenario | v1.0.0 | v1.2.0 | speed-up |
|---|---|---|---|
| match | 18.97 µs | 1.25 µs | 15.21× |
| push + pop | 124.52 µs | 110.58 µs | 1.13× |
| push 100 deep | 264.83 µs | 258.34 µs | 1.03× |
| deep link | 123.76 µs | 61.57 µs | 2.01× |
| dialog open + close | 72.37 µs | 72.29 µs | 1.00× |

Matching is a segment trie instead of one regex per registered page tried in order, so it no longer grows with the number of pages. A deep link no longer pops the stack one page at a time and goes through the matcher once. The frame (the navigator's own work) dominates the other scenarios.
