// BLoC 9: Cubit for values, cubits that listen to other cubits' streams for
// derived values, BlocBuilder widgets. Streams deliver asynchronously, so
// derived state is read after the events landed (settle()).
import 'dart:async';

import 'package:bench_kit/bench_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() => runBenchmarks(
      library: 'BLoC 9.2',
      notes: 'Cubit + stream.listen; derived values are cubits listening to '
          'other cubits; BlocBuilder; no batch API',
      core: _Core(),
      widgets: _Widgets(),
    );

class IntCubit extends Cubit<int> {
  IntCubit(super.initial);
  void set(int v) => emit(v);
}

/// A cubit whose state is computed from [sources] whenever one emits.
class DerivedCubit extends Cubit<int> {
  DerivedCubit(this.sources, this.compute) : super(compute()) {
    for (final s in sources) {
      _subs.add(s.stream.listen((_) => emit(compute())));
    }
  }

  final List<StateStreamable<int>> sources;
  final int Function() compute;
  final _subs = <StreamSubscription<int>>[];

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}

void _noopValue(int _) {}

class _Core extends CoreSuite {
  @override
  bool get asyncNotify => true;

  @override
  Bench subscribeShared(int listeners) {
    final cubit = IntCubit(0);
    final order = scatteredOrder(listeners);
    var calls = 0, base = 0;
    return Bench(
      opsPerRun: listeners,
      run: () async {
        final subs = [
          for (var i = 0; i < listeners; i++)
            cubit.stream.listen((_) => calls++)
        ];
        final start = calls;
        cubit.set(++base);
        await settle();
        check(calls - start == listeners, 'missed notifications');
        for (final i in order) {
          subs[i].cancel();
        }
        cubit.set(++base);
        await settle();
        check(calls - start == listeners, 'listener ran after removal');
      },
      dispose: cubit.close,
    );
  }

  @override
  MemoryProbe memory(int n) {
    late List<IntCubit> cells;
    late List<StreamSubscription<int>> subs;
    return MemoryProbe(
      create: () => cells = List.generate(n, IntCubit.new),
      listen: () => subs = [for (final c in cells) c.stream.listen(_noopValue)],
      dispose: () async {
        for (final s in subs) {
          await s.cancel();
        }
        for (final c in cells) {
          await c.close();
        }
      },
    );
  }

  @override
  Bench create(int n) => Bench(
        opsPerRun: n,
        run: () async {
          final cells = List.generate(n, IntCubit.new);
          var calls = 0;
          final subs = [
            for (final c in cells) c.stream.listen((_) => calls++)
          ];
          cells[0].set(-1);
          await settle();
          check(calls == 1, 'listener calls: $calls');
          for (final s in subs) {
            s.cancel();
          }
          for (final c in cells) {
            c.close();
          }
        },
      );

  @override
  Bench writeOneListener(int writes) {
    final cubit = IntCubit(0);
    var calls = 0, last = 0, base = 0;
    final sub = cubit.stream.listen((v) {
      calls++;
      last = v;
    });
    return Bench(
      opsPerRun: writes,
      run: () async {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          cubit.set(base + i);
        }
        base += writes;
        await settle();
        check(calls - start == writes && last == base, 'missed writes');
      },
      dispose: () {
        sub.cancel();
        cubit.close();
      },
    );
  }

  @override
  Bench fanOut(int listeners, int writes) {
    final cubit = IntCubit(0);
    var calls = 0, base = 0;
    final subs = [
      for (var i = 0; i < listeners; i++) cubit.stream.listen((_) => calls++)
    ];
    return Bench(
      opsPerRun: writes,
      run: () async {
        final start = calls;
        for (var i = 1; i <= writes; i++) {
          cubit.set(base + i);
        }
        base += writes;
        await settle();
        check(calls - start == writes * listeners, 'missed notifications');
      },
      dispose: () {
        for (final s in subs) {
          s.cancel();
        }
        cubit.close();
      },
    );
  }

  @override
  Bench wideDerived(int sources) {
    final cells = List.generate(sources, (_) => IntCubit(0));
    final sum = DerivedCubit(cells, () {
      var s = 0;
      for (final c in cells) {
        s += c.state;
      }
      return s;
    });
    var calls = 0;
    final sub = sum.stream.listen((_) => calls++);
    var expected = 0;
    return Bench(
      opsPerRun: sources,
      run: () async {
        for (final c in cells) {
          c.set(c.state + 1);
          expected++;
          await settle();
          check(sum.state == expected, 'stale sum');
        }
      },
      dispose: () {
        sub.cancel();
        sum.close();
      },
    );
  }

  @override
  Bench deepChain(int depth, int writes) {
    final root = IntCubit(0);
    final chain = <DerivedCubit>[];
    for (var i = 0; i < depth; i++) {
      final StateStreamable<int> prev = i == 0 ? root : chain[i - 1];
      chain.add(DerivedCubit([prev], () => prev.state + 1));
    }
    final tail = chain.last;
    final sub = tail.stream.listen((_) {});
    var base = 0;
    return Bench(
      opsPerRun: writes,
      run: () async {
        for (var i = 1; i <= writes; i++) {
          root.set(base + i);
          await settle();
          check(tail.state == base + i + depth, 'stale chain end');
        }
        base += writes;
      },
      dispose: () {
        sub.cancel();
        for (final c in chain) {
          c.close();
        }
      },
    );
  }

  @override
  Bench diamond(int writes) {
    final a = IntCubit(0);
    final b = DerivedCubit([a], () => a.state * 2);
    final c = DerivedCubit([a], () => a.state + 1);
    var dRuns = 0;
    final d = DerivedCubit([b, c], () {
      dRuns++;
      return b.state + c.state;
    });
    var calls = 0, glitches = 0, base = 0;
    final sub = d.stream.listen((v) {
      calls++;
      if (v != 3 * a.state + 1) glitches++;
    });
    var runCalls = 0, runGlitches = 0, runDRuns = 0;
    return Bench(
      opsPerRun: writes,
      run: () async {
        final c0 = calls, g0 = glitches, r0 = dRuns;
        for (var i = 1; i <= writes; i++) {
          a.set(base + i);
          await settle();
        }
        base += writes;
        check(d.state == 3 * base + 1, 'wrong final d');
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
        sub.cancel();
        d.close();
        b.close();
        c.close();
      },
    );
  }

  @override
  Bench batchUpdate(int sources, int rounds) {
    final cells = List.generate(sources, (_) => IntCubit(0));
    final sum = DerivedCubit(cells, () {
      var s = 0;
      for (final c in cells) {
        s += c.state;
      }
      return s;
    });
    var calls = 0, base = 0, runCalls = 0;
    final sub = sum.stream.listen((_) => calls++);
    return Bench(
      opsPerRun: rounds,
      run: () async {
        final c0 = calls;
        for (var r = 1; r <= rounds; r++) {
          final v = base + r;
          for (final c in cells) {
            c.set(v);
          }
          await settle();
          check(sum.state == v * sources, 'wrong sum');
        }
        base += rounds;
        runCalls = calls - c0;
      },
      metrics: () => {'listenerCallsPerRound': runCalls / rounds},
      dispose: () {
        sub.cancel();
        sum.close();
      },
    );
  }
}

class _Widgets extends WidgetSuite {
  late IntCubit shared;

  @override
  Widget sharedLeaf(int i) => BlocBuilder<IntCubit, int>(
        bloc: shared,
        builder: (_, v) => Leaf(v),
      );

  late List<IntCubit> cubits;

  @override
  void setup(int n) {
    cubits = List.generate(n, IntCubit.new);
    shared = IntCubit(7);
  }

  @override
  Widget leaf(int i) => BlocBuilder<IntCubit, int>(
        bloc: cubits[i],
        builder: (_, v) => Leaf(v),
      );

  @override
  void write(int i, int value) => cubits[i].set(value);

  @override
  void teardown() {
    shared.close();
    for (final c in cubits) {
      c.close();
    }
  }
}
