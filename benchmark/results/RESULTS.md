# Benchmark results

Apple M4 Pro, macOS 26.6.2 (Build 25G83), Flutter 3.50.0 • channel stable. Release (AOT) macOS builds; median time per run, best of 3 runs per library. Lower is better; **bold** is the fastest.

| Scenario | Fluxy | GetX 5 (upstream) | GetX 4.7.3 | Riverpod 3.5 | BLoC 9.2 | Signals 7.1 |
|---|---|---|---|---|---|---|
| Create + dispose | **37 µs** | 64 µs | 119 µs | 1.47 ms | 140 µs | 90 µs |
| Write, 1 listener | **99 µs** | 158 µs | 111 µs | 1.30 ms | 291 µs | 332 µs |
| Fan-out | **199 µs** | 246 µs | 601 µs | 1.45 ms | 2.50 ms | 2.78 ms |
| Subscribe + unsubscribe, shared | 1.06 ms | 9.41 ms | 1.28 ms | 852 µs | **80 µs** | 82 µs |
| Wide derived | 3.50 ms | 4.93 ms | **1.25 ms** | 2.25 s | 5.04 ms | 11.81 ms |
| Deep chain | 4.49 ms | 3.70 ms | **3.24 ms** | 393.85 ms | 9.09 ms | 3.25 ms |
| Diamond | 96 µs | 122 µs | **68 µs** | 10.98 ms | 4.61 ms | 114 µs |
| Batch update | **127 µs** | 5.18 ms | 1.40 ms | 5.39 ms | 1.26 ms | 181 µs |
| Mount + unmount | 1.04 ms | **1.04 ms** | 1.68 ms | 1.69 ms | 1.08 ms | 1.17 ms |
| Mount + unmount, shared value | 2.91 ms | 23.70 ms | 3.55 ms | 2.54 ms | **1.07 ms** | 1.12 ms |
| Rebuild all | **356 µs** | 408 µs | 375 µs | 577 µs | 429 µs | 452 µs |
| Rebuild one | 238 µs | 238 µs | **219 µs** | 224 µs | 240 µs | 238 µs |

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
| Fluxy | 185.0 | 205.0 |
| GetX 5 (upstream) | 168.0 | 175.0 |
| GetX 4.7.3 | 301.0 | 314.0 |
| Riverpod 3.5 | 1704.0 | 348.0 |
| BLoC 9.2 | 133.0 | 226.0 |
| Signals 7.1 | 365.0 | 415.0 |

Library versions: Fluxy (this repo); GetX 5 (upstream) (get 5.0.0-release-candidate-9.3.3); GetX 4.7.3 (get 4.7.3); Riverpod 3.5 (riverpod 3.5.0, flutter_riverpod 3.5.0); BLoC 9.2 (bloc 9.2.1, flutter_bloc 9.1.1); Signals 7.1 (signals 7.1.0, signals_core 7.0.0, signals_flutter 7.1.0)
