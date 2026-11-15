import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension on WidgetTester {
  Future<void> rebuild() async {
    await pump();
    await pump();
  }
}

void main() {
  group('Computed', () {
    test('computes lazily and caches until a source changes', () {
      final a = 2.obs;
      var runs = 0;
      final double = Computed(() {
        runs++;
        return a.value * 2;
      });
      expect(runs, 0, reason: 'nothing until the first read');
      expect(double.value, 4);
      expect(double.value, 4);
      expect(runs, 1);
      a.value = 3;
      expect(runs, 1, reason: 'no listeners: just marked stale');
      expect(double.value, 6);
      expect(runs, 2);
    });

    test('with a listener: notifies only when the result changes', () {
      final n = 1.obs;
      final isEven = Computed(() => n.value.isEven);
      var calls = 0;
      isEven.addListener(() => calls++);
      expect(isEven.value, isFalse);

      n.value = 3; // still odd
      expect(calls, 0);
      n.value = 4;
      expect(calls, 1);
      expect(isEven.peek, isTrue);
    });

    test('follows only the sources its last run read', () {
      final useA = true.obs;
      final a = 1.obs;
      final b = 10.obs;
      final pick = Computed(() => useA.value ? a.value : b.value);
      pick.addListener(() {});
      expect(pick.value, 1);
      expect(a.listenersLength, 1);

      useA.value = false;
      expect(pick.peek, 10);
      expect(a.listenersLength, 0);
      expect(b.listenersLength, 1);
    });

    test('a chain of computed values', () {
      final x = 1.obs;
      final y = Computed(() => x.value + 1);
      final z = Computed(() => y.value * 10);
      z.addListener(() {});
      expect(z.value, 20);
      x.value = 2;
      expect(z.peek, 30);
    });

    test('custom equals and dispose', () {
      final list = <int>[1].obs;
      final copy = Computed(() => [...list],
          equals: (a, b) => a.length == b.length);
      var calls = 0;
      copy.addListener(() => calls++);
      copy.value;
      list[0] = 5; // same length: not a change for equals
      expect(calls, 0);
      list.add(2);
      expect(calls, 1);
      copy.dispose();
      expect(list.listenersLength, 0);
    });

    testWidgets('an Obx rebuilds only when the computed result changes',
        (tester) async {
      final n = 1.obs;
      final parity = Computed(() => n.value.isEven ? 'even' : 'odd');
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          builds++;
          return Text(parity.value);
        }),
      ));
      expect(builds, 1);
      n.value = 3;
      await tester.rebuild();
      expect(builds, 1, reason: 'still odd');
      n.value = 4;
      await tester.rebuild();
      expect(builds, 2);
      expect(find.text('even'), findsOneWidget);
    });
  });

  group('RxFuture', () {
    test('loading, then success', () async {
      final f = RxFuture(() async => 42);
      expect(f.value.isLoading, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(f.value.isSuccess, isTrue);
      expect(f.value.data, 42);
      expect(f.lastData, 42);
    });

    test('error keeps the last data', () async {
      var fail = false;
      final f = RxFuture(() async {
        if (fail) throw StateError('down');
        return 'ok';
      });
      await Future<void>.delayed(Duration.zero);
      fail = true;
      await f.reload();
      expect(f.value.isError, isTrue);
      expect(f.value.error, isA<StateError>());
      expect(f.lastData, 'ok');
      expect(f.lastStackTrace, isNotNull);
    });

    test('a slow older load never overwrites a newer one', () async {
      final slow = Completer<String>();
      final fast = Completer<String>();
      var call = 0;
      final f = RxFuture(() => (++call == 1 ? slow : fast).future, lazy: true);
      final first = f.reload();
      final second = f.reload();
      fast.complete('new');
      await second;
      slow.complete('old');
      await first;
      expect(f.value.data, 'new');
    });

    test('when() picks the branch', () async {
      final f = RxFuture(() async => 1, lazy: true);
      String show() => f.when(
            loading: () => 'loading',
            success: (v) => 'v$v',
            error: (e) => 'error',
          );
      expect(show(), 'loading');
      await f.reload();
      expect(show(), 'v1');
    });
  });
}
