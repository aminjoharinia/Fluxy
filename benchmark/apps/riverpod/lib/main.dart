// Riverpod 3: NotifierProvider for values, Provider for derived values,
// ProviderContainer.listen, Consumer widgets.
import 'package:bench_kit/bench_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runBenchmarks(
      library: 'Riverpod 3.5',
      notes: 'NotifierProvider + Provider (ref.watch), container.listen, '
          'Consumer; no batch API (derived providers recompute lazily)',
      core: _Core(),
      widgets: _Widgets(),
    );

class Counter extends Notifier<int> {
  Counter(this.initial);
  final int initial;

  @override
  int build() => initial;

  void set(int v) => state = v;
}

NotifierProvider<Counter, int> _cell(int initial) =>
    NotifierProvider<Counter, int>(() => Counter(initial));

class _Core extends CoreSuite {
  /// Listeners of derived providers are notified when the container
  /// flushes (later), not inside the write.
  @override
  bool get asyncNotify => true;

  @override
  Bench subscribeShared(int listeners) {
    final container = ProviderContainer();
    final cell = _cell(0);
    final notifier = container.read(cell.notifier);
    final order = scatteredOrder(listeners);
    var calls = 0, base = 0;
    return Bench(
      opsPerRun: listeners,
      run: () async {
        final subs = [
          for (var i = 0; i < listeners; i++)
            container.listen<int>(cell, (_, __) => calls++)
        ];
        final start = calls;
        notifier.set(++base);
        if (calls - start != listeners) await settle();
        check(calls - start == listeners, 'missed notifications');
        for (final i in order) {
          subs[i].close();
        }
        notifier.set(++base);
        await settle();
        check(calls - start == listeners, 'listener ran after removal');
      },
      dispose: container.dispose,
    );
  }

  @override
  MemoryProbe memory(int n) {
    final container = ProviderContainer();
    late List<NotifierProvider<Counter, int>> cells;
    late List<ProviderSubscription<int>> subs;
    return MemoryProbe(
      create: () {
        cells = List.generate(n, _cell);
        for (final c in cells) {
          container.read(c);
        }
      },
      listen: () => subs = [
        for (final c in cells) container.listen<int>(c, (_, __) {})
      ],
      dispose: () {
        for (final s in subs) {
          s.close();
        }
        container.dispose();
      },
    );
  }

  @override
  Bench create(int n) => Bench(
        opsPerRun: n,
        run: () {
          final container = ProviderContainer();
          final cells = List.generate(n, _cell);
          var calls = 0;
          final subs = [
            for (final c in cells) container.listen(c, (_, __) => calls++)
          ];
          container.read(cells[0].notifier).set(-1);
          check(calls == 1, 'listener calls: $calls');
          for (final s in subs) {
            s.close();
          }
          container.dispose();
        },
      );

  @override
  Bench writeOneListener(int writes) {
    final container = ProviderContainer();
    final cell = _cell(0);
    var calls = 0, last = 0, base = 0;
    final sub = container.listen<int>(cell, (_, next) {
      calls++;
      last = next;
    });
    final notifier = container.read(cell.notifier);
    return Bench(
      opsPerRun: writes,
      run: () async {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          notifier.set(base + i);
        }
        base += writes;
        if (calls - start != writes) await settle();
        check(calls - start == writes && last == base,
            'missed writes: ${calls - start}');
      },
      dispose: () {
        sub.close();
        container.dispose();
      },
    );
  }

  @override
  Bench fanOut(int listeners, int writes) {
    final container = ProviderContainer();
    final cell = _cell(0);
    var calls = 0, base = 0;
    final subs = [
      for (var i = 0; i < listeners; i++)
        container.listen<int>(cell, (_, __) => calls++)
    ];
    final notifier = container.read(cell.notifier);
    return Bench(
      opsPerRun: writes,
      run: () async {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          notifier.set(base + i);
        }
        base += writes;
        if (calls - start != writes * listeners) await settle();
        check(calls - start == writes * listeners, 'missed notifications');
      },
      dispose: () {
        for (final s in subs) {
          s.close();
        }
        container.dispose();
      },
    );
  }

  @override
  Bench wideDerived(int sources) {
    final container = ProviderContainer();
    final cells = List.generate(sources, (_) => _cell(0));
    final sum = Provider<int>((ref) {
      var s = 0;
      for (final c in cells) {
        s += ref.watch(c);
      }
      return s;
    });
    var calls = 0;
    final sub = container.listen<int>(sum, (_, __) => calls++);
    final notifiers = [for (final c in cells) container.read(c.notifier)];
    var expected = 0;
    return Bench(
      opsPerRun: sources,
      run: () {
        for (var i = 0; i < sources; i++) {
          final n = notifiers[i];
          n.set(container.read(cells[i]) + 1);
          expected++;
          check(container.read(sum) == expected, 'stale sum');
        }
      },
      dispose: () {
        sub.close();
        container.dispose();
      },
    );
  }

  @override
  Bench deepChain(int depth, int writes) {
    final container = ProviderContainer();
    final root = _cell(0);
    final chain = <Provider<int>>[];
    for (var i = 0; i < depth; i++) {
      final prev = i == 0 ? null : chain[i - 1];
      chain.add(Provider<int>(
          (ref) => (prev == null ? ref.watch(root) : ref.watch(prev)) + 1));
    }
    final tail = chain.last;
    final sub = container.listen<int>(tail, (_, __) {});
    final notifier = container.read(root.notifier);
    var base = 0;
    return Bench(
      opsPerRun: writes,
      run: () {
        for (var i = 1; i <= writes; i++) {
          notifier.set(base + i);
          check(container.read(tail) == base + i + depth, 'stale chain end');
        }
        base += writes;
      },
      dispose: () {
        sub.close();
        container.dispose();
      },
    );
  }

  @override
  Bench diamond(int writes) {
    final container = ProviderContainer();
    final a = _cell(0);
    final b = Provider<int>((ref) => ref.watch(a) * 2);
    final c = Provider<int>((ref) => ref.watch(a) + 1);
    var dRuns = 0;
    final d = Provider<int>((ref) {
      dRuns++;
      return ref.watch(b) + ref.watch(c);
    });
    var calls = 0, glitches = 0, base = 0;
    final sub = container.listen<int>(d, (_, next) {
      calls++;
      if (next != 3 * container.read(a) + 1) glitches++;
    });
    final notifier = container.read(a.notifier);
    var runCalls = 0, runGlitches = 0, runDRuns = 0;
    return Bench(
      opsPerRun: writes,
      run: () async {
        final c0 = calls, g0 = glitches, r0 = dRuns;
        for (var i = 1; i <= writes; i++) {
          final before = calls;
          notifier.set(base + i);
          // Wait for the listener only when it was not called right away.
          if (calls == before) await settle();
        }
        base += writes;
        check(container.read(d) == 3 * base + 1, 'wrong final d');
        runCalls = calls - c0;
        runGlitches = glitches - g0;
        runDRuns = dRuns - r0;
      },
      metrics: () => {
        'listenerCallsPerWrite': runCalls / writes,
        'glitchesPerWrite': runGlitches / writes,
        'recomputesPerWrite': runDRuns / writes,
      },
      dispose: () {
        sub.close();
        container.dispose();
      },
    );
  }

  @override
  Bench batchUpdate(int sources, int rounds) {
    final container = ProviderContainer();
    final cells = List.generate(sources, (_) => _cell(0));
    final sum = Provider<int>((ref) {
      var s = 0;
      for (final c in cells) {
        s += ref.watch(c);
      }
      return s;
    });
    var calls = 0, base = 0, runCalls = 0;
    final sub = container.listen<int>(sum, (_, __) => calls++);
    final notifiers = [for (final c in cells) container.read(c.notifier)];
    return Bench(
      opsPerRun: rounds,
      run: () async {
        final c0 = calls;
        for (var r = 1; r <= rounds; r++) {
          final v = base + r;
          final before = calls;
          for (final n in notifiers) {
            n.set(v);
          }
          check(container.read(sum) == v * sources, 'wrong sum');
          if (calls == before) await settle();
        }
        base += rounds;
        runCalls = calls - c0;
      },
      metrics: () => {'listenerCallsPerRound': runCalls / rounds},
      dispose: () {
        sub.close();
        container.dispose();
      },
    );
  }
}

class _Widgets extends WidgetSuite {
  final shared = _cell(7);

  @override
  Widget sharedLeaf(int i) =>
      Consumer(builder: (_, ref, __) => Leaf(ref.watch(shared)));

  final container = ProviderContainer();
  late List<NotifierProvider<Counter, int>> cells;
  late List<Counter?> notifiers;

  @override
  Widget wrap(Widget child) =>
      UncontrolledProviderScope(container: container, child: child);

  @override
  void setup(int n) {
    cells = List.generate(n, _cell);
    notifiers = List.filled(n, null);
  }

  @override
  Widget leaf(int i) =>
      Consumer(builder: (_, ref, __) => Leaf(ref.watch(cells[i])));

  @override
  void write(int i, int value) {
    final cached = notifiers[i];
    if (cached != null) return cached.set(value);
    final Counter created = container.read(cells[i].notifier);
    notifiers[i] = created;
    created.set(value);
  }

  @override
  void teardown() => container.dispose();
}
