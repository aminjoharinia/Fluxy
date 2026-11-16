# Fluxy benchmark

Fluxy against GetX 4 (pub.dev stable), upstream GetX 5 at `a294d2f` (the commit Fluxy was forked from), Riverpod, BLoC and Signals: core reactivity (writes, listeners, derived values, batching) and widget rebuilds. The latest numbers are in [results/RESULTS.md](results/RESULTS.md).

## How it works

- `bench_kit/` is the shared harness. It defines the scenarios ([`CoreSuite`](bench_kit/lib/src/harness.dart) and [`WidgetSuite`](bench_kit/lib/src/widgets.dart)), times them the same way for every library, checks every result, and writes JSON.
- `apps/<library>/` is one small macOS app per library, each implementing the scenarios with that library's own API. They are separate apps because Fluxy, GetX 4 and GetX 5 are all named `get`.
- Every app is built with `flutter build macos --release`, so the timings come from ahead-of-time compiled code, not the debug VM.
- A scenario warms up for 5 runs, then is sampled for about 2.5 seconds (at least 15 runs); the median is reported. `run.sh` runs each app 3 times and `summarize.py` keeps the lowest median of the runs.
- Each run checks its own result: a missed notification, a stale derived value or a wrong number of rebuilt widgets fails the scenario instead of producing a fast wrong number.
- Libraries that notify asynchronously (Riverpod's scheduled flush, BLoC's streams) wait for the event loop where a synchronous library would read right away; that wait is part of their real cost.
- GetX 4 and GetX 5 have no computed values or batching, so their derived values are wired by hand with listeners, as apps on them do. That is also why they show glitches in the diamond scenario.
- Widget scenarios drive frames directly (build, layout, paint) after letting pending notifications land, so frame timing is not tied to the display's refresh rate.

## Scenarios

| Scenario | One run |
|---|---|
| Create + dispose | 1,000 reactive values, one listener each, then disposed |
| Write, 1 listener | 10,000 writes to one value with one listener |
| Fan-out | 100 writes to one value with 1,000 listeners |
| Wide derived | 1,000 sources summed by one derived value; each source written once, the sum read after every write |
| Deep chain | a chain of 100 derived values; 1,000 writes to the root, the end read after every write |
| Diamond | a → b, c → d = b + c with a listener; 1,000 writes; also counts glitches |
| Batch update | 100 sources and a derived sum; 100 rounds that change every source (batched where possible) |
| Mount + unmount | 1,000 reactive widgets mounted, one frame, unmounted, one frame |
| Rebuild all | all 1,000 values written, one frame rebuilding all 1,000 widgets |
| Rebuild one of 1,000 | one value written, one frame that must rebuild exactly that widget |

## Running it

Needs macOS with Xcode and Flutter (desktop enabled). From the repo root:

```bash
benchmark/run.sh
```

```bash
RUNS=1 benchmark/run.sh fluxy riverpod
```

```bash
python3 benchmark/report.py
```

`run.sh` writes `results/<library>-<n>.json` and `results/summary.json`; `report.py` turns the summary into `results/RESULTS.md` and the CSV files in `results/report/`. Library versions are pinned by each app's `pubspec.lock`; `flutter pub upgrade` in an app moves it to newer releases.

The numbers depend on the machine; compare libraries within one run of the suite, not across machines.

## Charts in the app

Opened by hand (not from `run.sh`), each benchmark app shows a page instead of running headless. It has a Run button and progress, and for every scenario a bar chart comparing this run with the saved results of all six libraries (`results/summary.json`, found by walking up from the app). Below the charts is the correctness table. Bars are on a linear scale, capped at 8× the fastest. A bar past the cap is drawn broken, and its label says how many times slower it is. Results that are fast but wrong (diamond glitches, a batch notifying once per write) are marked ⚠.

```bash
cd benchmark/apps/fluxy && flutter run -d macos --release
```

The window repaints between scenarios, so its numbers are noisier than `run.sh`'s. `run.sh` builds with `BENCH_OUT` and never shows the page.
