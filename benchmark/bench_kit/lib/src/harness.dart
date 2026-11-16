import 'dart:async';
import 'dart:io' show ProcessInfo;

/// One measurable piece of work. [run] is timed; it must leave the state as
/// it found it (or reset it itself) so it can be repeated, and it checks its
/// own result by throwing [BenchFailure] when the library got it wrong.
class Bench {
  Bench({
    required this.run,
    required this.opsPerRun,
    this.metrics,
    this.dispose,
  });

  final FutureOr<void> Function() run;

  /// How many operations one [run] does (writes, widgets, ...), for the
  /// per-operation time.
  final int opsPerRun;

  /// Counters read after the last run (notifications, glitches ...).
  final Map<String, num> Function()? metrics;
  final void Function()? dispose;
}

/// A wrong result: the benchmark is reported as invalid with [message].
class BenchFailure implements Exception {
  BenchFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

void check(bool ok, String message) {
  if (!ok) throw BenchFailure(message);
}

/// Waits until every pending microtask and stream event was delivered (for
/// libraries that notify asynchronously).
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// The core (widget-free) scenarios. Each library writes them with its own
/// idiomatic API.
abstract class CoreSuite {
  /// True when listeners / derived values only see a change after the event
  /// loop turns (stream based). Scenarios then [settle] where a synchronous
  /// library would read right away.
  bool get asyncNotify;

  /// Create [n] reactive values with one listener each, then dispose all.
  Bench create(int n);

  /// One value, one listener, [writes] writes. Every write must reach the
  /// listener (asynchronous libraries may deliver them later).
  Bench writeOneListener(int writes);

  /// One value, [listeners] listeners, [writes] writes.
  Bench fanOut(int listeners, int writes);

  /// [sources] values and one derived sum of all of them (with a listener);
  /// each source is written once and the sum read after every write.
  Bench wideDerived(int sources);

  /// A chain of [depth] derived values (each = previous + 1); [writes]
  /// writes to the root, the end of the chain read after every write.
  Bench deepChain(int depth, int writes);

  /// a -> b = a * 2, c = a + 1, d = b + c with a listener. [writes] writes to
  /// a. Metrics: listener calls, and glitches (the listener saw a d that
  /// does not match a: a new b with an old c).
  Bench diamond(int writes);

  /// [sources] values and a derived sum with a listener; each round changes
  /// every source (inside the library's batch, if it has one), then reads
  /// the sum. Metric: listener calls per round (ideal: 1).
  Bench batchUpdate(int sources, int rounds);

  /// One value; each run subscribes [listeners] listeners, writes once
  /// (all must hear it), unsubscribes them in a scattered order
  /// ([scatteredOrder]: widgets are not disposed in the order they
  /// subscribed), and writes again (none may hear it).
  Bench subscribeShared(int listeners);

  /// [n] values held alive, then one listener each, for [measureMemory].
  MemoryProbe memory(int n);
}

/// The steps [measureMemory] takes for one library.
class MemoryProbe {
  MemoryProbe({
    required this.create,
    required this.listen,
    required this.dispose,
  });

  /// Creates the values and keeps them (no listeners yet).
  final void Function() create;

  /// Subscribes one listener to each value and keeps the subscriptions.
  final FutureOr<void> Function() listen;
  final FutureOr<void> Function() dispose;
}

/// 0 .. n-1 in a scattered order (a stride coprime with [n]).
List<int> scatteredOrder(int n) {
  var stride = 7919; // prime, larger than every size's listener count
  while (n % stride == 0) {
    stride += 2;
  }
  return [for (var k = 0; k < n; k++) (k * stride) % n];
}

/// Values [measureMemory] creates, the same at every size: enough that the
/// growth of the process's memory is mostly the values themselves.
const memoryValues = 200000;

/// Where the churn's garbage lives briefly. A ring the result reads, so
/// the compiler can neither drop the allocations nor keep them off the heap.
final _churnRing = List<List<int>?>.filled(256, null);

/// Resident memory once what survived so far has left the young
/// generation: short-lived garbage forces a few scavenges first, so values
/// still in the young generation are not counted in a later phase (and the
/// young generation is at full size in every reading).
int _settledRss() {
  var check = 0;
  for (var i = 0; i < 1 << 20; i++) {
    _churnRing[i & 255] = List<int>.filled(8, i);
    check ^= _churnRing[(i * 7) & 255]?[i & 7] ?? 0;
  }
  _churnRing.fillRange(0, 256, null);
  // Never true; keeps `check` (and so the reads) alive.
  if (check == -1) throw StateError('unreachable');
  return ProcessInfo.currentRss;
}

/// How much memory a value and a subscription take: the growth of the
/// process's resident memory while [memoryValues] values are created and
/// then subscribed. Measured once, first thing in a fresh process (later,
/// freed memory would be reused and hide the growth), so it is a rough
/// figure; summarize.py keeps the lowest of the runs.
Future<Map<String, Object?>> measureMemory(CoreSuite suite,
    {int n = memoryValues}) async {
  try {
    final probe = suite.memory(n);
    await settle();
    final rss0 = _settledRss();
    final sw = Stopwatch()..start();
    probe.create();
    sw.stop();
    final rss1 = _settledRss();
    sw.start();
    final r = probe.listen();
    if (r is Future) await r;
    sw.stop();
    final rss2 = _settledRss();
    final d = probe.dispose();
    if (d is Future) await d;
    final us = sw.elapsedMicroseconds;
    return {
      'id': 'memory',
      'ok': true,
      'medianUs': us,
      'p25Us': us,
      'p75Us': us,
      'minUs': us,
      'samples': 1,
      'opsPerRun': n,
      'nsPerOp': us * 1000 / n,
      'metrics': {
        'bytesPerValue': ((rss1 - rss0) / n).roundToDouble(),
        'bytesPerListener': ((rss2 - rss1) / n).roundToDouble(),
      },
    };
  } catch (e) {
    return {'id': 'memory', 'ok': false, 'error': '$e'};
  }
}

/// How much work each scenario does: the same scenarios at the scale of a
/// tiny app, a normal one (the published numbers), a heavy one and a super
/// app. Saved results exist per size (`results/summary.json` for normal,
/// `results/<size>/summary.json` for the others; `SIZE=heavy run.sh`).
enum BenchSize {
  tiny('tiny', 'Tiny app',
      cells: 100,
      writes: 1000,
      listeners: 100,
      wide: 100,
      chainDepth: 20,
      chainWrites: 100,
      diamond: 100,
      batchSources: 20,
      batchRounds: 20,
      widgets: 100),
  normal('normal', 'Normal app',
      cells: 1000,
      writes: 10000,
      listeners: 1000,
      wide: 1000,
      chainDepth: 100,
      chainWrites: 1000,
      diamond: 1000,
      batchSources: 100,
      batchRounds: 100,
      widgets: 1000),
  heavy('heavy', 'Heavy app',
      cells: 5000,
      writes: 50000,
      listeners: 5000,
      wide: 2500,
      chainDepth: 250,
      chainWrites: 1000,
      diamond: 5000,
      batchSources: 300,
      batchRounds: 100,
      widgets: 5000,
      warmup: 3,
      minSamples: 8),
  superApp('super', 'Super app',
      cells: 20000,
      writes: 200000,
      listeners: 20000,
      wide: 5000,
      chainDepth: 500,
      chainWrites: 1000,
      diamond: 20000,
      batchSources: 1000,
      batchRounds: 100,
      widgets: 20000,
      warmup: 2,
      minSamples: 5);

  const BenchSize(
    this.key,
    this.label, {
    required this.cells,
    required this.writes,
    required this.listeners,
    required this.wide,
    required this.chainDepth,
    required this.chainWrites,
    required this.diamond,
    required this.batchSources,
    required this.batchRounds,
    required this.widgets,
    this.warmup = 5,
    this.minSamples = 15,
  });

  /// Used in file names and `--dart-define=BENCH_SIZE=...`.
  final String key;
  final String label;

  /// Create + dispose: reactive values created.
  final int cells;

  /// Write, 1 listener: writes.
  final int writes;

  /// Fan-out: listeners on the one value (100 writes).
  final int listeners;

  /// Wide derived: sources summed.
  final int wide;
  final int chainDepth;
  final int chainWrites;

  /// Diamond: writes.
  final int diamond;
  final int batchSources;
  final int batchRounds;

  /// Widget scenarios: reactive widgets on screen.
  final int widgets;

  final int warmup;
  final int minSamples;

  static const fanOutWrites = 100;

  static BenchSize fromKey(String key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => BenchSize.normal,
      );
}

/// 12345 -> "12,345".
String formatCount(int n) {
  final s = '$n';
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class ScenarioInfo {
  const ScenarioInfo(this.id, this.title, this.group, {this.opLabel = 'op'});
  final String id;
  final String title;
  final String group;
  final String opLabel;

  /// What one run does at [size].
  String describe(BenchSize size) {
    final f = formatCount;
    final w = f(size.widgets);
    return switch (id) {
      'create' => '${f(size.cells)} reactive values, one listener each, '
          'then disposed.',
      'write' => '${f(size.writes)} writes to one value with one listener.',
      'fanout' => '${BenchSize.fanOutWrites} writes to one value with '
          '${f(size.listeners)} listeners.',
      'subscribe' => '${f(size.listeners)} listeners subscribe to one value '
          'and unsubscribe in a scattered order, with a write in between.',
      'wide' => '${f(size.wide)} sources summed by one derived value; each '
          'source written once, the sum read after every write.',
      'chain' => 'A chain of ${f(size.chainDepth)} derived values; '
          '${f(size.chainWrites)} writes to the root, the end read after '
          'every write.',
      'diamond' => 'a -> b, c -> d = b + c with a listener; '
          '${f(size.diamond)} writes. Also counts glitches: the listener '
          'seeing a d that does not match a.',
      'batch' => '${f(size.batchSources)} sources and a derived sum with a '
          'listener; ${f(size.batchRounds)} rounds that change every source '
          '(batched where the library can), then read the sum.',
      'mount' => 'Mount $w reactive widgets (each subscribing to its own '
          'value), one frame, then unmount them, one frame.',
      'mountShared' => 'Mount $w reactive widgets that all read the same '
          'value, one frame, then unmount them, one frame.',
      'rebuildAll' =>
        'Write all $w values, then one frame that rebuilds all $w widgets.',
      'rebuildOne' => 'Write one of $w values, then one frame that must '
          'rebuild exactly that widget.',
      _ => title,
    };
  }

  String get description => describe(BenchSize.normal);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'group': group,
        'description': description,
        'opLabel': opLabel,
      };
}

const scenarioInfos = <ScenarioInfo>[
  ScenarioInfo('create', 'Create + dispose', 'core', opLabel: 'value'),
  ScenarioInfo('write', 'Write, 1 listener', 'core', opLabel: 'write'),
  ScenarioInfo('fanout', 'Fan-out', 'core', opLabel: 'write'),
  ScenarioInfo('subscribe', 'Subscribe + unsubscribe, shared', 'core',
      opLabel: 'listener'),
  ScenarioInfo('wide', 'Wide derived', 'core', opLabel: 'write'),
  ScenarioInfo('chain', 'Deep chain', 'core', opLabel: 'write'),
  ScenarioInfo('diamond', 'Diamond (glitches)', 'core', opLabel: 'write'),
  ScenarioInfo('batch', 'Batch update', 'core', opLabel: 'round'),
  ScenarioInfo('mount', 'Mount + unmount', 'widget', opLabel: 'widget'),
  ScenarioInfo('mountShared', 'Mount + unmount, shared value', 'widget',
      opLabel: 'widget'),
  ScenarioInfo('rebuildAll', 'Rebuild all', 'widget', opLabel: 'widget'),
  ScenarioInfo('rebuildOne', 'Rebuild one', 'widget', opLabel: 'frame'),
];

/// Times [bench]: warm-up runs, then samples until [budget] is spent (at
/// least [minSamples], at most [maxSamples]). Reports the median.
///
/// A run slower than [slowRun] (a library that does not scale to a big
/// size) cuts the warm-up short and needs only 3 samples; past [slowRun] x 4
/// that warm-up run is the one sample, so one slow library cannot stall the
/// suite for long;
/// the result's `samples` says how many it got.
Future<Map<String, Object?>> measure(
  String id,
  Bench Function() make, {
  int warmup = 5,
  int minSamples = 15,
  int maxSamples = 400,
  Duration budget = const Duration(milliseconds: 2500),
  Duration slowRun = const Duration(seconds: 2),
}) async {
  Bench? bench;
  try {
    bench = make();
    Future<void> once() async {
      final r = bench!.run();
      if (r is Future) await r;
    }

    var slowest = Duration.zero;
    final samples = <int>[];
    for (var i = 0; i < warmup; i++) {
      final sw = Stopwatch()..start();
      await once();
      if (sw.elapsed > slowest) slowest = sw.elapsed;
      // So slow that warming up changes nothing: this run is the sample.
      if (slowest > slowRun * 4) samples.add(sw.elapsedMicroseconds);
      if (slowest > slowRun) break;
    }
    final total = Stopwatch()..start();
    bool enough() {
      if (slowest > slowRun * 4) return samples.isNotEmpty;
      if (slowest > slowRun) return samples.length >= 3;
      return samples.length >= minSamples &&
          (total.elapsed >= budget || samples.length >= maxSamples);
    }

    while (!enough()) {
      final sw = Stopwatch()..start();
      final r = bench.run();
      if (r is Future) await r;
      sw.stop();
      if (sw.elapsed > slowest) slowest = sw.elapsed;
      samples.add(sw.elapsedMicroseconds);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    final p25 = samples[samples.length ~/ 4];
    final p75 = samples[(samples.length * 3) ~/ 4];
    return {
      'id': id,
      'ok': true,
      'medianUs': median,
      'p25Us': p25,
      'p75Us': p75,
      'minUs': samples.first,
      'samples': samples.length,
      'opsPerRun': bench.opsPerRun,
      'nsPerOp': median * 1000 / bench.opsPerRun,
      'metrics': bench.metrics?.call() ?? const <String, num>{},
    };
  } catch (e) {
    return {'id': id, 'ok': false, 'error': '$e'};
  } finally {
    try {
      bench?.dispose?.call();
    } catch (_) {}
  }
}

/// Called before a scenario starts (the UI shows it; awaited, so it can
/// let a frame through first).
typedef ScenarioStart = Future<void> Function(String id);

/// Called with each scenario's result as soon as it is measured.
typedef ScenarioResult = void Function(Map<String, Object?> result);

/// Runs every core scenario of [suite] at [size].
Future<List<Map<String, Object?>>> runCore(
  CoreSuite suite, {
  BenchSize size = BenchSize.normal,
  ScenarioStart? onStart,
  ScenarioResult? onResult,
}) async {
  Future<Map<String, Object?>> step(String id, Bench Function() make) async {
    await onStart?.call(id);
    final result = await measure(id, make,
        warmup: size.warmup, minSamples: size.minSamples);
    onResult?.call(result);
    return result;
  }

  final s = size;
  return [
    await step('create', () => suite.create(s.cells)),
    await step('write', () => suite.writeOneListener(s.writes)),
    await step('fanout', () => suite.fanOut(s.listeners, BenchSize.fanOutWrites)),
    await step('subscribe', () => suite.subscribeShared(s.listeners)),
    await step('wide', () => suite.wideDerived(s.wide)),
    await step('chain', () => suite.deepChain(s.chainDepth, s.chainWrites)),
    await step('diamond', () => suite.diamond(s.diamond)),
    await step('batch', () => suite.batchUpdate(s.batchSources, s.batchRounds)),
  ];
}
