// Fluxy (this repo): Rx + Computed + Fluxy.batch, Obx.
import 'package:bench_kit/bench_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:fluxy/fluxy.dart';

void main() => runBenchmarks(
      library: 'Fluxy',
      notes: 'Rx.addListener, glitch-free Computed, Fluxy.batch, Obx',
      core: _Core(),
      widgets: _Widgets(),
    );

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
          for (var i = 0; i < listeners; i++) rx.addListener(() => calls++)
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
      listen: () => removers = [for (final c in cells) c.addListener(_noop)],
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
          final removers = [for (final c in cells) c.addListener(() => calls++)];
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
    final remove = rx.addListener(() {
      calls++;
      last = rx.peek;
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
      for (var i = 0; i < listeners; i++) rx.addListener(() => calls++)
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
    final sum = Computed(() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    });
    var calls = 0;
    final remove = sum.addListener(() => calls++);
    var expected = 0;
    return Bench(
      opsPerRun: sources,
      run: () {
        for (final c in cells) {
          c.value = c.peek + 1;
          expected++;
          check(sum.value == expected, 'stale sum');
        }
      },
      dispose: () {
        remove();
        sum.dispose();
      },
    );
  }

  @override
  Bench deepChain(int depth, int writes) {
    final root = 0.obs;
    final chain = <Computed<int>>[];
    for (var i = 0; i < depth; i++) {
      final prev = i == 0 ? null : chain[i - 1];
      chain.add(Computed(() => (prev == null ? root.value : prev.value) + 1));
    }
    final tail = chain.last;
    final remove = tail.addListener(() {});
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
        remove();
        for (final c in chain) {
          c.dispose();
        }
      },
    );
  }

  @override
  Bench diamond(int writes) {
    final a = 0.obs;
    final b = Computed(() => a.value * 2);
    final c = Computed(() => a.value + 1);
    var dRuns = 0;
    final d = Computed(() {
      dRuns++;
      return b.value + c.value;
    });
    var calls = 0, glitches = 0, base = 0;
    final remove = d.addListener(() {
      calls++;
      if (d.peek != 3 * a.peek + 1) glitches++;
    });
    d.peek;
    var runCalls = 0, runGlitches = 0, runDRuns = 0;
    return Bench(
      opsPerRun: writes,
      run: () {
        final c0 = calls, g0 = glitches, r0 = dRuns;
        for (var i = 1; i <= writes; i++) {
          a.value = base + i;
        }
        base += writes;
        check(d.peek == 3 * base + 1, 'wrong final d');
        runCalls = calls - c0;
        runGlitches = glitches - g0;
        runDRuns = dRuns - r0;
      },
      metrics: () => {
        'listenerCallsPerWrite': runCalls / writes,
        'glitchesPerWrite': runGlitches / writes,
        'recomputesPerWrite': runDRuns / writes,
      },
      dispose: remove,
    );
  }

  @override
  Bench batchUpdate(int sources, int rounds) {
    final cells = List<RxInt>.generate(sources, (_) => RxInt(0));
    final sum = Computed(() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    });
    var calls = 0, base = 0, runCalls = 0;
    final remove = sum.addListener(() => calls++);
    sum.peek;
    return Bench(
      opsPerRun: rounds,
      run: () {
        final c0 = calls;
        for (var r = 1; r <= rounds; r++) {
          final v = base + r;
          Fluxy.batch(() {
            for (final c in cells) {
              c.value = v;
            }
          });
          check(sum.value == v * sources, 'wrong sum');
        }
        base += rounds;
        runCalls = calls - c0;
      },
      metrics: () => {'listenerCallsPerRound': runCalls / rounds},
      dispose: () {
        remove();
        sum.dispose();
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
