// GetX 4.7.3 (pub.dev stable): Rx.listen (GetStream, synchronous), Obx.
// No Computed and no batch in this version: derived values are wired by hand
// with listeners (each recomputes from its sources), as apps on it do.
import 'package:bench_kit/bench_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:get/state_manager.dart';

void main() => runBenchmarks(
      library: 'GetX 4.7.3',
      notes: 'pub.dev stable; Rx.listen (synchronous GetStream); derived values by hand; Obx',
      core: _Core(),
      widgets: _Widgets(),
    );

/// Listens to [rx] (GetStream subscription, delivered synchronously).
void Function() _on(RxInt rx, void Function() listener) {
  final sub = rx.listen((_) => listener());
  return sub.cancel;
}

void _noop() {}

class _Core extends CoreSuite {
  @override
  bool get asyncNotify => false;

  @override
  Bench subscribeShared(int listeners) {
    final rx = 0.obs;
    final order = scatteredOrder(listeners);
    var calls = 0, base = 0;
    return Bench(
      opsPerRun: listeners,
      run: () {
        final removers = [
          for (var i = 0; i < listeners; i++) _on(rx, () => calls++)
        ];
        final start = calls;
        rx.value = ++base;
        check(calls - start == listeners, 'missed notifications');
        for (final i in order) {
          removers[i]();
        }
        rx.value = ++base;
        check(calls - start == listeners, 'listener ran after removal');
      },
      dispose: rx.close,
    );
  }

  @override
  MemoryProbe memory(int n) {
    late List<RxInt> cells;
    late List<void Function()> removers;
    return MemoryProbe(
      create: () => cells = List<RxInt>.generate(n, RxInt.new),
      listen: () => removers = [for (final c in cells) _on(c, _noop)],
      dispose: () {
        for (final r in removers) {
          r();
        }
        for (final c in cells) {
          c.close();
        }
      },
    );
  }

  @override
  Bench create(int n) => Bench(
        opsPerRun: n,
        run: () {
          final cells = List<RxInt>.generate(n, RxInt.new);
          var calls = 0;
          final removers = [for (final c in cells) _on(c, () => calls++)];
          cells[0].value = -1;
          check(calls == 1, 'listener calls: $calls');
          for (final r in removers) {
            r();
          }
          for (final c in cells) {
            c.close();
          }
        },
      );

  @override
  Bench writeOneListener(int writes) {
    final rx = 0.obs;
    var calls = 0, last = 0, base = 0;
    final remove = _on(rx, () {
      calls++;
      last = rx.value;
    });
    return Bench(
      opsPerRun: writes,
      run: () {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          rx.value = base + i;
        }
        base += writes;
        check(calls - start == writes && last == base, 'missed writes');
      },
      dispose: () {
        remove();
        rx.close();
      },
    );
  }

  @override
  Bench fanOut(int listeners, int writes) {
    final rx = 0.obs;
    var calls = 0, base = 0;
    final removers = [
      for (var i = 0; i < listeners; i++) _on(rx, () => calls++)
    ];
    return Bench(
      opsPerRun: writes,
      run: () {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          rx.value = base + i;
        }
        base += writes;
        check(calls - start == writes * listeners, 'missed notifications');
      },
      dispose: () {
        for (final r in removers) {
          r();
        }
        rx.close();
      },
    );
  }

  @override
  Bench wideDerived(int sources) {
    final cells = List<RxInt>.generate(sources, (_) => RxInt(0));
    final sum = 0.obs;
    int compute() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    }

    final removers = [for (final c in cells) _on(c, () => sum.value = compute())];
    var calls = 0;
    removers.add(_on(sum, () => calls++));
    var expected = 0;
    return Bench(
      opsPerRun: sources,
      run: () {
        for (final c in cells) {
          c.value = c.value + 1;
          expected++;
          check(sum.value == expected, 'stale sum');
        }
      },
      dispose: () {
        for (final r in removers) {
          r();
        }
      },
    );
  }

  @override
  Bench deepChain(int depth, int writes) {
    final root = 0.obs;
    final chain = List<RxInt>.generate(depth, (i) => RxInt(i + 1));
    final removers = <void Function()>[];
    for (var i = 0; i < depth; i++) {
      final prev = i == 0 ? root : chain[i - 1];
      final node = chain[i];
      removers.add(_on(prev, () => node.value = prev.value + 1));
    }
    final tail = chain.last;
    removers.add(_on(tail, () {}));
    var base = 0;
    return Bench(
      opsPerRun: writes,
      run: () {
        for (var i = 1; i <= writes; i++) {
          root.value = base + i;
          check(tail.value == base + i + depth, 'stale chain end');
        }
        base += writes;
      },
      dispose: () {
        for (final r in removers) {
          r();
        }
      },
    );
  }

  @override
  Bench diamond(int writes) {
    final a = 0.obs;
    final b = 0.obs;
    final c = 1.obs;
    final d = 1.obs;
    var dRuns = 0;
    void recomputeD() {
      dRuns++;
      d.value = b.value + c.value;
    }

    var calls = 0, glitches = 0, base = 0;
    final removers = [
      _on(a, () => b.value = a.value * 2),
      _on(a, () => c.value = a.value + 1),
      _on(b, recomputeD),
      _on(c, recomputeD),
      _on(d, () {
        calls++;
        if (d.value != 3 * a.value + 1) glitches++;
      }),
    ];
    var runCalls = 0, runGlitches = 0, runDRuns = 0;
    return Bench(
      opsPerRun: writes,
      run: () {
        final c0 = calls, g0 = glitches, r0 = dRuns;
        for (var i = 1; i <= writes; i++) {
          a.value = base + i;
        }
        base += writes;
        check(d.value == 3 * base + 1, 'wrong final d');
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
        for (final r in removers) {
          r();
        }
      },
    );
  }

  @override
  Bench batchUpdate(int sources, int rounds) {
    final cells = List<RxInt>.generate(sources, (_) => RxInt(0));
    final sum = 0.obs;
    int compute() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    }

    final removers = [for (final c in cells) _on(c, () => sum.value = compute())];
    var calls = 0, base = 0, runCalls = 0;
    removers.add(_on(sum, () => calls++));
    return Bench(
      opsPerRun: rounds,
      run: () {
        final c0 = calls;
        for (var r = 1; r <= rounds; r++) {
          final v = base + r;
          for (final c in cells) {
            c.value = v;
          }
          check(sum.value == v * sources, 'wrong sum');
        }
        base += rounds;
        runCalls = calls - c0;
      },
      metrics: () => {'listenerCallsPerRound': runCalls / rounds},
      dispose: () {
        for (final r in removers) {
          r();
        }
      },
    );
  }
}

class _Widgets extends WidgetSuite {
  late RxInt shared;

  @override
  Widget sharedLeaf(int i) => Obx(() => Leaf(shared.value));

  late List<RxInt> values;

  @override
  void setup(int n) {
    values = List<RxInt>.generate(n, RxInt.new);
    shared = RxInt(7);
  }

  @override
  Widget leaf(int i) => Obx(() => Leaf(values[i].value));

  @override
  void write(int i, int value) => values[i].value = value;

  @override
  void teardown() {
    shared.close();
    for (final v in values) {
      v.close();
    }
  }
}
