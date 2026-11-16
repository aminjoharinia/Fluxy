# Benchmark results

Apple M4 Pro, macOS 26.6.2 (Build 25G83), Flutter 3.50.0 • channel stable. Release (AOT) macOS builds; median time per run, best of 3 runs per library. Lower is better; **bold** is the fastest.

| Scenario | Fluxy | GetX 5 (upstream) | GetX 4.7.3 | Riverpod 3.5 | BLoC 9.2 | Signals 7.1 |
|---|---|---|---|---|---|---|
| Create + dispose | **34 µs** | 64 µs | 97 µs | 1.47 ms | 138 µs | 89 µs |
| Write, 1 listener | **83 µs** | 158 µs | 108 µs | 1.29 ms | 295 µs | 329 µs |
| Fan-out | **213 µs** | 234 µs | 591 µs | 1.51 ms | 2.54 ms | 2.67 ms |
| Subscribe + unsubscribe, shared | **26 µs** | 9.34 ms | 1.27 ms | 850 µs | 80 µs | 81 µs |
| Wide derived | 2.67 ms | 4.88 ms | **1.26 ms** | 2.24 s | 4.97 ms | 11.63 ms |
| Deep chain | **2.98 ms** | 3.56 ms | 3.13 ms | 381.97 ms | 9.02 ms | 3.24 ms |
| Diamond | 85 µs | 122 µs | **68 µs** | 11.19 ms | 4.59 ms | 114 µs |
| Batch update | **109 µs** | 5.12 ms | 1.42 ms | 5.37 ms | 1.24 ms | 179 µs |
| Mount + unmount | 1.03 ms | **1.03 ms** | 1.65 ms | 1.61 ms | 1.05 ms | 1.10 ms |
| Mount + unmount, shared value | **1.01 ms** | 23.38 ms | 3.50 ms | 2.50 ms | 1.03 ms | 1.08 ms |
| Rebuild all | **346 µs** | 406 µs | 376 µs | 568 µs | 430 µs | 447 µs |
| Rebuild one | 233 µs | 236 µs | **220 µs** | 221 µs | 238 µs | 237 µs |

## Correctness

| Library | Diamond: listener calls / write | glitches / write | d recomputes / write | Batch: listener calls / round |
|---|---|---|---|---|
| Fluxy | 1.0 | 0.0 | 1.0 | 1.0 |
| GetX 5 (upstream) | 2.0 | 1.0 | 2.0 | 100.0 |
| GetX 4.7.3 | 2.0 | 1.0 | 2.0 | 100.0 |
| Riverpod 3.5 | 1.0 | 0.0 | 1.0 | 1.0 |
| BLoC 9.2 | 1.0 | 0.0 | 2.0 | 1.0 |
| Signals 7.1 | 1.0 | 0.0 | 1.0 | 1.0 |

## Memory

Growth of the process's resident memory while 200,000 values are created, then while each gets one listener (lowest of the runs; a rough figure).

| Library | Bytes / value | Bytes / listener |
|---|---|---|
| Fluxy | 185.0 | 237.0 |
| GetX 5 (upstream) | 168.0 | 178.0 |
| GetX 4.7.3 | 301.0 | 317.0 |
| Riverpod 3.5 | 1709.0 | 337.0 |
| BLoC 9.2 | 133.0 | 228.0 |
| Signals 7.1 | 364.0 | 416.0 |

Library versions: Fluxy (this repo); GetX 5 (upstream) (get 5.0.0-release-candidate-9.3.3); GetX 4.7.3 (get 4.7.3); Riverpod 3.5 (riverpod 3.5.0, flutter_riverpod 3.5.0); BLoC 9.2 (bloc 9.2.1, flutter_bloc 9.1.1); Signals 7.1 (signals 7.1.0, signals_core 7.0.0, signals_flutter 7.1.0)
