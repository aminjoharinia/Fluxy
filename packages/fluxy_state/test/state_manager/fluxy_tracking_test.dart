import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension on WidgetTester {
  // Obx marks itself dirty in a microtask, so it takes two pumps.
  Future<void> rebuild() async {
    await pump();
    await pump();
  }
}

// Dependency tracking: reads matched by position, the index built only past
// a few sources, and what an observer keeps after a build that threw.
void main() {
  group('TrackedSources', () {
    test('many sources, read in a different order each run', () {
      final cells = List<RxInt>.generate(20, RxInt.new);
      final order = List<int>.generate(20, (i) => i);
      var runs = 0;
      final sum = Computed(() {
        runs++;
        var s = 0;
        for (final i in order) {
          s += cells[i].value;
          s += cells[i].value; // second read in the same run is ignored
        }
        return s;
      });
      var calls = 0;
      sum.addListener(() => calls++);
      expect(sum.value, 2 * 190);

      order.setAll(0, order.reversed.toList());
      cells[3].value = 103;
      expect(sum.value, 2 * 290);

      // Drop half the sources: the dropped ones no longer recompute it.
      order.removeRange(10, 20);
      cells[0].value = 1000; // still read (reversed order put 19..10 first)
      final afterDrop = runs;
      cells[19].value = 5000; // read
      expect(runs, afterDrop + 1);
      cells[0].value = 2000; // index 0 is no longer read
      expect(runs, afterDrop + 1);
      expect(calls, greaterThan(0));
    });

    test('a few sources, a duplicate read in the middle of the same order',
        () {
      final a = 1.obs, b = 2.obs, c = 3.obs;
      var runs = 0;
      final v = Computed(() {
        runs++;
        return a.value + b.value + a.value + c.value;
      });
      v.addListener(() {});
      expect(v.value, 7);
      b.value = 20;
      expect(v.value, 25);
      c.value = 30;
      expect(v.value, 52);
      a.value = 10;
      expect(v.value, 70);
      expect(runs, 4);
    });

    test('a source read only in some runs is subscribed and dropped', () {
      final flag = true.obs;
      final x = 1.obs, y = 2.obs;
      var runs = 0;
      final v = Computed(() {
        runs++;
        return flag.value ? x.value : y.value;
      });
      v.addListener(() {});
      expect(v.value, 1);
      flag.value = false;
      expect(v.value, 2);
      final r = runs;
      x.value = 100; // no longer read
      expect(runs, r);
      y.value = 200;
      expect(v.value, 200);
      expect(runs, r + 1);
    });
  });

  group('Obx', () {
    testWidgets('stops rebuilding for a value its build no longer reads',
        (tester) async {
      final show = true.obs;
      final a = 0.obs, b = 0.obs;
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          builds++;
          return Text(show.value ? '${a.value}' : '${b.value}');
        }),
      ));
      expect(builds, 1);
      show.value = false;
      await tester.rebuild();
      expect(builds, 2);
      a.value = 1; // dropped
      await tester.rebuild();
      expect(builds, 2);
      b.value = 1;
      await tester.rebuild();
      expect(builds, 3);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a build that threw still rebuilds on every value it read',
        (tester) async {
      final a = 0.obs, b = 0.obs, broken = false.obs;
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          builds++;
          final s = '${a.value}';
          if (broken.value) {
            b.value; // read out of the last order, then throw
            throw StateError('boom');
          }
          return Text(s);
        }),
      ));
      broken.value = true;
      await tester.rebuild();
      expect(tester.takeException(), isA<StateError>());
      final afterThrow = builds;

      // Both the old sources and the one read before the throw still
      // rebuild it.
      broken.value = false;
      await tester.rebuild();
      expect(builds, afterThrow + 1);
      expect(find.text('0'), findsOneWidget);
      a.value = 7;
      await tester.rebuild();
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('mark, then pull', () {
    test('an upstream result that did not change skips the recompute', () {
      final a = 1.obs;
      var parityRuns = 0, labelRuns = 0;
      final odd = Computed(() {
        parityRuns++;
        return a.value.isOdd;
      });
      final label = Computed(() {
        labelRuns++;
        return odd.value ? 'odd' : 'even';
      });
      var calls = 0;
      label.addListener(() => calls++);
      expect(label.value, 'odd');
      final p0 = parityRuns, l0 = labelRuns;

      a.value = 3; // still odd
      expect(parityRuns, p0 + 1);
      expect(labelRuns, l0, reason: 'odd did not change, label is kept');
      expect(calls, 0);

      a.value = 4;
      expect(labelRuns, l0 + 1);
      expect(calls, 1);
      expect(label.value, 'even');
    });

    test('a write it does not read leaves a subscribed Computed alone', () {
      final a = 1.obs, other = 0.obs;
      var runs = 0;
      final c = Computed(() {
        runs++;
        return a.value * 2;
      });
      c.addListener(() {});
      expect(c.value, 2);
      final r = runs;
      other.value = 1;
      expect(c.value, 2);
      expect(runs, r);
    });

    test('listeners of a Computed run after the source listeners', () {
      final a = 0.obs;
      final c = Computed(() => a.value + 1);
      final log = <String>[];
      c.addListener(() => log.add('computed ${c.peek}'));
      a.addListener(() => log.add('source ${a.peek}'));
      a.value = 1;
      expect(log, ['source 1', 'computed 2']);
    });

    test('inside a batch: fresh reads, one notification after it', () {
      final a = 1.obs, b = 2.obs;
      final sum = Computed(() => a.value + b.value);
      var calls = 0;
      sum.addListener(() => calls++);
      Get.batch(() {
        a.value = 10;
        expect(sum.value, 12);
        b.value = 20;
        expect(sum.value, 30);
        expect(calls, 0);
      });
      expect(calls, 1);
    });

    test('a listener added later is not told about an older change', () {
      final a = 1.obs;
      final mid = Computed(() => a.value * 2);
      final top = Computed(() => mid.value + 1);
      top.addListener(() {}); // mid is subscribed only as a source of top
      a.value = 2; // mid changes while nobody listens to it directly
      expect(top.value, 5);
      var calls = 0;
      mid.addListener(() => calls++);
      a.value = 2; // no change
      expect(calls, 0);
      a.value = 3;
      expect(calls, 1);
      expect(mid.value, 6);
    });

    test('a source Computed sleeps when its last dependent leaves', () {
      final a = 1.obs;
      final mid = Computed(() => a.value * 2);
      final top = Computed(() => mid.value + 1);
      final remove = top.addListener(() {});
      expect(top.value, 3);
      expect(mid.dependentsLength, 1);
      expect(a.dependentsLength, 1);
      remove();
      expect(mid.dependentsLength, 0);
      expect(a.dependentsLength, 0);
      a.value = 5;
      expect(top.value, 11, reason: 'still right when read while asleep');
    });

    test('a long chain recomputes each link once per write', () {
      final root = 0.obs;
      var runs = 0;
      final chain = <Computed<int>>[];
      for (var i = 0; i < 200; i++) {
        final prev = i == 0 ? null : chain[i - 1];
        chain.add(Computed(() {
          runs++;
          return (prev == null ? root.value : prev.value) + 1;
        }));
      }
      var calls = 0;
      chain.last.addListener(() => calls++);
      runs = 0;
      root.value = 1;
      expect(runs, 200);
      expect(calls, 1);
      expect(chain.last.value, 201);
    });
  });
}
