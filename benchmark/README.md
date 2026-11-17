# Fluxy benchmark

Fluxy against GetX 4 (pub.dev stable), upstream GetX 5 at `a294d2f` (the commit Fluxy was forked from), Riverpod, BLoC and Signals: core reactivity (writes, listeners, derived values, batching) and widget rebuilds. The latest numbers are in [results/RESULTS.md](results/RESULTS.md). Navigation (matching, push / pop, deep links, dialogs, against an older Fluxy) has its own app in [nav/](nav/README.md).

## How it works

- `bench_kit/` is the shared harness. It defines the scenarios ([`CoreSuite`](bench_kit/lib/src/harness.dart) and [`WidgetSuite`](bench_kit/lib/src/widgets.dart)), times them the same way for every library, checks every result, and writes JSON.
- `apps/<library>/` is one small macOS app per library, each implementing the scenarios with that library's own API. They are separate apps because GetX 4 and GetX 5 are both named `get` (Fluxy was too, until it became `fluxy`).
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
| Subscribe + unsubscribe, shared | 1,000 listeners subscribe to one value and unsubscribe in a scattered order, with a write in between |
| Wide derived | 1,000 sources summed by one derived value; each source written once, the sum read after every write |
| Deep chain | a chain of 100 derived values; 1,000 writes to the root, the end read after every write |
| Diamond | a → b, c → d = b + c with a listener; 1,000 writes; also counts glitches |
| Batch update | 100 sources and a derived sum; 100 rounds that change every source (batched where possible) |
| Mount + unmount | 1,000 reactive widgets mounted, one frame, unmounted, one frame |
| Mount + unmount, shared value | the same with all 1,000 widgets reading one value |
| Rebuild all | all 1,000 values written, one frame rebuilding all 1,000 widgets |
| Rebuild one of 1,000 | one value written, one frame that must rebuild exactly that widget |

Memory is measured once per run, first thing in a fresh process: the growth of resident memory while 200,000 values are created, then while each gets one listener, with a burst of short-lived garbage before each reading so survivors have left the young generation. It is a rough figure (bytes per value and per listener, the lowest of the runs), but it repeats within a few bytes.

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

### App sizes

The scenarios above are the **normal app** size, the published numbers. `SIZE` runs the same scenarios scaled to other app sizes and writes `results/<size>/` instead of `results/`:

```bash
SIZE=heavy benchmark/run.sh
```

| Size | Values / widgets | Writes | Fan-out listeners | Wide sources | Chain | Diamond writes | Batch |
|---|---|---|---|---|---|---|---|
| `tiny` | 100 | 1,000 | 100 | 100 | 20 × 100 writes | 100 | 20 × 20 rounds |
| `normal` | 1,000 | 10,000 | 1,000 | 1,000 | 100 × 1,000 writes | 1,000 | 100 × 100 rounds |
| `heavy` | 5,000 | 50,000 | 5,000 | 2,500 | 250 × 1,000 writes | 5,000 | 300 × 100 rounds |
| `super` | 20,000 | 200,000 | 20,000 | 5,000 | 500 × 1,000 writes | 20,000 | 1,000 × 100 rounds |

Heavy and super need fewer samples (8 and 5, after 3 and 2 warm-up runs). A library whose single run takes more than 2 seconds at a size stops after 3 samples, or 1 past 8 seconds, so one library that does not scale cannot stall the suite; the result's `samples` says how many it got.

## Charts in the app

Opened by hand (not from `run.sh`), each benchmark app shows a page instead of running headless. It has a Run button and progress, an app-size picker (tiny, normal, heavy, super), a light / dark switch, and for every scenario a bar chart comparing this run with the saved results of all six libraries at the picked size (`results/summary.json` or `results/<size>/summary.json`, found by walking up from the app). Each library has its own color, and the fastest bar gets a trophy. Below the charts is the correctness table. Bars are on a linear scale, capped at 8× the fastest. A bar past the cap is drawn broken, and its label says how many times slower it is. Results that are fast but wrong (diamond glitches, a batch notifying once per write) are marked ⚠.

```bash
cd benchmark/apps/fluxy && flutter run -d macos --release
```

The window repaints between scenarios, so its numbers are noisier than `run.sh`'s. `run.sh` builds with `BENCH_OUT` and never shows the page.
