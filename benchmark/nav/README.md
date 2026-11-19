# Navigation, dependency and reactive-read benchmark

Release (AOT) macOS app timing fluxy_nav, fluxy_state's dependency injection and reactive reads over large collections, compared with an older Fluxy version built from a temporary git worktree. Only API both versions share is used; `lib/adapter.dart` holds the version-specific calls (`adapter_v1_0.dart.txt` for versions before v1.2.0).

| Scenario | One op |
|---|---|
| match | match one address against 152 pages (100 static, 50 `/:id`, a 6-level nested chain): the last static page, a parameter page, the deepest nested page, an unknown address, the first static page |
| push + pop | `Fluxy.toNamed` + one frame, `Fluxy.back` + one frame |
| push 100 deep | `Fluxy.toNamed` + one frame on a growing stack (1 to 100 pages), then `offAllNamed` (counted in) |
| deep link | `Fluxy.offAllNamed` to a nested or parameter page + one frame |
| dialog open + close | `Fluxy.dialog` + frame, `Fluxy.back` + frame |
| di find | `Fluxy.find` of a `put` controller (two per loop step, counted as one op) |
| di put + delete | `Fluxy.put` of a controller (started) + `Fluxy.delete(force: true)` (closed) |
| di lazyPut + find + delete | `Fluxy.lazyPut`, `find` (built, started), `delete(force: true)` |
| page with bindings push + pop | `toNamed` to a page whose `Binding` lazily registers a controller it finds, + frame, `back` + two frames (dependencies closed) |
| rx list loop [i] 5k | recompute a `Computed` that reads 6 `RxInt`s then loops `rows[i]` over a 5,000-row `RxList<Map>`, after an in-place edit + `refresh()` |
| rx list fold 5k | the same with `rows.fold` |
| rx list any + firstWhere 5k | the same with `rows.any` (no hit) + `rows.firstWhere` (last row) |
| rx map forEach 2k | the same with `forEach` over a 2,000-entry `RxMap` |

Pages have no transition, so each frame finishes its route changes. Each scenario: one warm-up, 15 samples, median; the table keeps the lowest median of the runs, which alternate old / new builds.

```bash
benchmark/nav/run.sh          # this checkout against v1.0.0
```

## Results (2026-11-19, unreleased against v1.4.0, 4 runs each, Apple silicon)

| Scenario | v1.4.0 | this checkout | speed-up |
|---|---|---|---|
| rx list loop [i] 5k | 81.64 µs | 38.66 µs | 2.11× |
| rx list fold 5k | 85.03 µs | 30.77 µs | 2.76× |
| rx list any + firstWhere 5k | 175.31 µs | 65.78 µs | 2.67× |
| rx map forEach 2k | 28.49 µs | 4.07 µs | 7.00× |

Navigation and DI rows unchanged (0.97–1.05×). A repeated read of the same list is one identity check, and the collection read methods read the list once.

## Results (2026-11-18, v1.4.0 against v1.3.0, 4 runs each, Apple silicon)

| Scenario | v1.3.0 | v1.4.0 | speed-up |
|---|---|---|---|
| match | 1.29 µs | 1.28 µs | 1.01× |
| push + pop | 117.92 µs | 121.36 µs | 0.97× |
| push 100 deep | 274.19 µs | 260.59 µs | 1.05× |
| deep link | 61.29 µs | 59.86 µs | 1.02× |
| dialog open + close | 71.69 µs | 77.04 µs | 0.93× |
| di find | 0.02 µs | 0.01 µs | 1.36× |
| di put + delete | 1.28 µs | 0.65 µs | 1.96× |
| di lazyPut + find + delete | 1.25 µs | 0.68 µs | 1.85× |
| page with bindings push + pop | 122.89 µs | 123.80 µs | 0.99× |

The registry no longer keeps "dirty" entries, route links or a SmartManagement check, and `find` is one map lookup when no page scope is open. The navigation rows are the frame and run-to-run noise.

## Results (2026-11-17, v1.2.0 against v1.0.0, 4 runs each, Apple silicon)

| Scenario | v1.0.0 | v1.2.0 | speed-up |
|---|---|---|---|
| match | 18.97 µs | 1.25 µs | 15.21× |
| push + pop | 124.52 µs | 110.58 µs | 1.13× |
| push 100 deep | 264.83 µs | 258.34 µs | 1.03× |
| deep link | 123.76 µs | 61.57 µs | 2.01× |
| dialog open + close | 72.37 µs | 72.29 µs | 1.00× |

Matching is a segment trie instead of one regex per registered page tried in order, so it no longer grows with the number of pages. A deep link no longer pops the stack one page at a time and goes through the matcher once. The frame (the navigator's own work) dominates the other scenarios.
