// Signals 7 (preact-signals style): signal, computed, subscribe, batch, SignalBuilder.
import 'package:bench_kit/bench_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:signals/signals_flutter.dart';

void main() => runBenchmarks(
      library: 'Signals 7.1',
      notes: 'signal / computed / subscribe / batch, SignalBuilder widget',
      core: _Core(),
      widgets: _Widgets(),
    );

/// subscribe() calls the listener once right away; skip that call.
void Function() _on<T>(ReadonlySignal<T> s, void Function() listener) {
  var first = true;
  return s.subscribe((_) {
    if (first) {
      first = false;
      return;
    }
    listener();
  });
}

class _Core extends CoreSuite {
  @override
  bool get asyncNotify => false;

  @override
  Bench create(int n) => Bench(
        opsPerRun: n,
        run: () {
          final cells = List.generate(n, (i) => signal(i));
          var calls = 0;
          final removers = [for (final c in cells) _on(c, () => calls++)];
          cells[0].value = -1;
          check(calls == 1, 'listener calls: $calls');
          for (final r in removers) {
            r();
          }
          for (final c in cells) {
            c.dispose();
          }
        },
      );

  @override
  Bench writeOneListener(int writes) {
    final s = signal(0);
    var calls = 0, last = 0, base = 0;
    final remove = _on(s, () {
      calls++;
      last = s.peek();
    });
    return Bench(
      opsPerRun: writes,
      run: () {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          s.value = base + i;
        }
        base += writes;
        check(calls - start == writes && last == base, 'missed writes');
      },
      dispose: remove,
    );
  }

  @override
  Bench fanOut(int listeners, int writes) {
    final s = signal(0);
    var calls = 0, base = 0;
    final removers = [
      for (var i = 0; i < listeners; i++) _on(s, () => calls++)
    ];
    return Bench(
      opsPerRun: writes,
      run: () {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          s.value = base + i;
        }
        base += writes;
        check(calls - start == writes * listeners, 'missed notifications');
      },
      dispose: () {
        for (final r in removers) {
          r();
        }
      },
    );
  }

  @override
  Bench wideDerived(int sources) {
    final cells = List.generate(sources, (_) => signal(0));
    final sum = computed(() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    });
    var calls = 0;
    final remove = _on(sum, () => calls++);
    var expected = 0;
    return Bench(
      opsPerRun: sources,
      run: () {
        for (final c in cells) {
          c.value = c.peek() + 1;
          expected++;
          check(sum.value == expected, 'stale sum');
        }
      },
      dispose: remove,
    );
  }

  @override
  Bench deepChain(int depth, int writes) {
    final root = signal(0);
    final chain = <ReadonlySignal<int>>[];
    for (var i = 0; i < depth; i++) {
      final prev = i == 0 ? null : chain[i - 1];
      chain.add(computed(() => (prev == null ? root.value : prev.value) + 1));
    }
    final tail = chain.last;
    final remove = _on(tail, () {});
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
      dispose: remove,
    );
  }

  @override
  Bench diamond(int writes) {
    final a = signal(0);
    final b = computed(() => a.value * 2);
    final c = computed(() => a.value + 1);
    var dRuns = 0;
    final d = computed(() {
      dRuns++;
      return b.value + c.value;
    });
    var calls = 0, glitches = 0, base = 0;
    final remove = _on(d, () {
      calls++;
      if (d.peek() != 3 * a.peek() + 1) glitches++;
    });
    var runCalls = 0, runGlitches = 0, runDRuns = 0;
    return Bench(
      opsPerRun: writes,
      run: () {
        final c0 = calls, g0 = glitches, r0 = dRuns;
        for (var i = 1; i <= writes; i++) {
          a.value = base + i;
        }
        base += writes;
        check(d.peek() == 3 * base + 1, 'wrong final d');
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
    final cells = List.generate(sources, (_) => signal(0));
    final sum = computed(() {
      var s = 0;
      for (final c in cells) {
        s += c.value;
      }
      return s;
    });
    var calls = 0, base = 0, runCalls = 0;
    final remove = _on(sum, () => calls++);
    return Bench(
      opsPerRun: rounds,
      run: () {
        final c0 = calls;
        for (var r = 1; r <= rounds; r++) {
          final v = base + r;
          batch(() {
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
      dispose: remove,
    );
  }
}

class _Widgets extends WidgetSuite {
  late List<Signal<int>> values;

  @override
  void setup(int n) => values = List.generate(n, (i) => signal(i));

  @override
  Widget leaf(int i) => SignalBuilder(builder: (_) => Leaf(values[i].value));

  @override
  void write(int i, int value) => values[i].value = value;

  @override
  void teardown() {
    for (final v in values) {
      v.dispose();
    }
  }
}
