# Benchmark results

Apple M4 Pro, macOS 26.6.2 (Build 25G83), Flutter 3.50.0 • channel stable. Release (AOT) macOS builds; median time per run, best of 3 runs per library. Lower is better; **bold** is the fastest.

| Scenario | Fluxy | GetX 5 (upstream) | GetX 4.7.3 | Riverpod 3.5 | BLoC 9.2 | Signals 7.1 |
|---|---|---|---|---|---|---|
| Create + dispose | **64 µs** | **64 µs** | 100 µs | 1.49 ms | 143 µs | 92 µs |
| Write, 1 listener | **98 µs** | 162 µs | 109 µs | 1.43 ms | 295 µs | 318 µs |
| Fan-out | **176 µs** | 261 µs | 593 µs | 1.47 ms | 2.53 ms | 2.86 ms |
| Wide derived | 4.55 ms | 5.19 ms | **1.20 ms** | 2.33 s | 7.60 ms | 10.69 ms |
| Deep chain | 5.19 ms | 3.86 ms | 3.29 ms | 400.03 ms | 11.38 ms | **3.27 ms** |
| Diamond | 117 µs | 119 µs | **70 µs** | 11.24 ms | 7.11 ms | 113 µs |
| Batch update | 458 µs | 5.47 ms | 1.42 ms | 5.65 ms | 1.47 ms | **182 µs** |
| Mount + unmount | 1.28 ms | **1.06 ms** | 1.68 ms | 1.68 ms | 1.19 ms | 1.24 ms |
| Rebuild all | 391 µs | 401 µs | **379 µs** | 563 µs | 427 µs | 452 µs |
| Rebuild one of 1,000 | 234 µs | 233 µs | 231 µs | **216 µs** | 233 µs | 236 µs |

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
