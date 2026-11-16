# Benchmark results

Apple M4 Pro, macOS 26.6.2 (Build 25G83), Flutter 3.50.0 • channel stable. Release (AOT) macOS builds; median time per run, best of 3 runs per library. Lower is better; **bold** is the fastest.

| Scenario | Fluxy | GetX 5 (upstream) | GetX 4.7.3 | Riverpod 3.5 | BLoC 9.2 | Signals 7.1 |
|---|---|---|---|---|---|---|
| Create + dispose | 65 µs | **63 µs** | 101 µs | 1.48 ms | 140 µs | 90 µs |
| Write, 1 listener | **100 µs** | 162 µs | 107 µs | 1.30 ms | 289 µs | 313 µs |
| Fan-out | **183 µs** | 249 µs | 583 µs | 1.46 ms | 2.49 ms | 2.76 ms |
| Wide derived | 3.40 ms | 4.92 ms | **1.22 ms** | 2.27 s | 7.62 ms | 10.82 ms |
| Deep chain | 4.04 ms | 3.49 ms | **2.99 ms** | 379.10 ms | 11.34 ms | 3.19 ms |
| Diamond | 92 µs | 115 µs | **68 µs** | 11.37 ms | 7.08 ms | 115 µs |
| Batch update | **132 µs** | 5.18 ms | 1.41 ms | 5.41 ms | 1.49 ms | 178 µs |
| Mount + unmount | **1.03 ms** | 1.04 ms | 1.59 ms | 1.71 ms | 1.10 ms | 1.21 ms |
| Rebuild all | **334 µs** | 397 µs | 373 µs | 556 µs | 419 µs | 447 µs |
| Rebuild one of 1,000 | **215 µs** | 226 µs | 229 µs | 217 µs | 234 µs | 232 µs |

## Correctness

| Library | Diamond: listener calls / write | glitches / write | d recomputes / write | Batch: listener calls / round |
|---|---|---|---|---|
| Fluxy | 1.0 | 0.0 | 1.0 | 1.0 |
| GetX 5 (upstream) | 2.0 | 1.0 | 2.0 | 100.0 |
| GetX 4.7.3 | 2.0 | 1.0 | 2.0 | 100.0 |
| Riverpod 3.5 | 1.0 | 0.0 | 1.0 | 1.0 |
| BLoC 9.2 | 1.0 | 0.0 | 2.0 | 1.0 |
| Signals 7.1 | 1.0 | 0.0 | 1.0 | 1.0 |

Library versions: Fluxy (this repo); GetX 5 (upstream) (get 5.0.0-release-candidate-9.3.3); GetX 4.7.3 (get 4.7.3); Riverpod 3.5 (riverpod 3.5.0, flutter_riverpod 3.5.0); BLoC 9.2 (bloc 9.2.1, flutter_bloc 9.1.1); Signals 7.1 (signals 7.1.0, signals_core 7.0.0, signals_flutter 7.1.0)
