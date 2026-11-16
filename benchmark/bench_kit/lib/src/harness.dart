import 'dart:async';

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
}

class ScenarioInfo {
  const ScenarioInfo(this.id, this.title, this.group, this.description,
      {this.opLabel = 'op'});
  final String id;
  final String title;
  final String group;
  final String description;
  final String opLabel;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'group': group,
        'description': description,
        'opLabel': opLabel,
      };
}

const scenarioInfos = <ScenarioInfo>[
  ScenarioInfo('create', 'Create + dispose', 'core',
      '1,000 reactive values, one listener each, then disposed.',
      opLabel: 'value'),
  ScenarioInfo('write', 'Write, 1 listener', 'core',
      '10,000 writes to one value with one listener.',
      opLabel: 'write'),
  ScenarioInfo('fanout', 'Fan-out', 'core',
      '100 writes to one value with 1,000 listeners.',
      opLabel: 'write'),
  ScenarioInfo('wide', 'Wide derived', 'core',
      '1,000 sources summed by one derived value; each source written once, '
          'the sum read after every write.',
      opLabel: 'write'),
  ScenarioInfo('chain', 'Deep chain', 'core',
      'A chain of 100 derived values; 1,000 writes to the root, the end read '
          'after every write.',
      opLabel: 'write'),
  ScenarioInfo('diamond', 'Diamond (glitches)', 'core',
      'a -> b, c -> d = b + c with a listener; 1,000 writes. Also counts '
          'glitches: the listener seeing a d that does not match a.',
      opLabel: 'write'),
  ScenarioInfo('batch', 'Batch update', 'core',
      '100 sources and a derived sum with a listener; 100 rounds that change '
          'every source (batched where the library can), then read the sum.',
      opLabel: 'round'),
  ScenarioInfo('mount', 'Mount + unmount', 'widget',
      'Mount 1,000 reactive widgets (each subscribing to its own value), one '
          'frame, then unmount them, one frame.',
      opLabel: 'widget'),
  ScenarioInfo('rebuildAll', 'Rebuild all', 'widget',
      'Write all 1,000 values, then one frame that rebuilds all 1,000 '
          'widgets.',
      opLabel: 'widget'),
  ScenarioInfo('rebuildOne', 'Rebuild one of 1,000', 'widget',
      'Write one of 1,000 values, then one frame that must rebuild exactly '
          'that widget.',
      opLabel: 'frame'),
];

/// Times [bench]: warm-up runs, then samples until [budget] is spent (at
/// least [minSamples], at most [maxSamples]). Reports the median.
Future<Map<String, Object?>> measure(
  String id,
  Bench Function() make, {
  int warmup = 5,
  int minSamples = 15,
  int maxSamples = 400,
  Duration budget = const Duration(milliseconds: 2500),
}) async {
  Bench? bench;
  try {
    bench = make();
    Future<void> once() async {
      final r = bench!.run();
      if (r is Future) await r;
    }

    for (var i = 0; i < warmup; i++) {
      await once();
    }
    final samples = <int>[];
    final total = Stopwatch()..start();
    while (samples.length < minSamples ||
        (total.elapsed < budget && samples.length < maxSamples)) {
      final sw = Stopwatch()..start();
      final r = bench.run();
      if (r is Future) await r;
      sw.stop();
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

/// Runs every core scenario of [suite].
Future<List<Map<String, Object?>>> runCore(
  CoreSuite suite, {
  ScenarioStart? onStart,
  ScenarioResult? onResult,
}) async {
  Future<Map<String, Object?>> step(String id, Bench Function() make) async {
    await onStart?.call(id);
    final result = await measure(id, make);
    onResult?.call(result);
    return result;
  }

  return [
    await step('create', () => suite.create(1000)),
    await step('write', () => suite.writeOneListener(10000)),
    await step('fanout', () => suite.fanOut(1000, 100)),
    await step('wide', () => suite.wideDerived(1000)),
    await step('chain', () => suite.deepChain(100, 1000)),
    await step('diamond', () => suite.diamond(1000)),
    await step('batch', () => suite.batchUpdate(100, 100)),
  ];
}
