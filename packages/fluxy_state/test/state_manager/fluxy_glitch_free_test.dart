import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

void main() {
  group('Computed is glitch-free', () {
    test('diamond: a listener never sees a new b with an old c', () {
      final a = 1.obs;
      final b = Computed(() => a.value * 2);
      final c = Computed(() => a.value + 1);
      var dRuns = 0;
      final d = Computed(() {
        dRuns++;
        return b.value + c.value;
      });
      final seen = <int>[];
      d.addListener(() => seen.add(d.peek));
      expect(d.peek, 4);
      expect(dRuns, 1);

      a.value = 5;
      expect(seen, [16], reason: 'one notification, consistent value');
      expect(dRuns, 2, reason: 'd recomputes once, not once per path');
    });

    test('diamond without listeners: one run per read after a change', () {
      final a = 1.obs;
      var bRuns = 0, cRuns = 0, dRuns = 0;
      final b = Computed(() {
        bRuns++;
        return a.value * 2;
      });
      final c = Computed(() {
        cRuns++;
        return a.value + 1;
      });
      final d = Computed(() {
        dRuns++;
        return b.value + c.value;
      });
      expect(d.value, 4);
      a.value = 2;
      a.value = 3;
      expect(d.value, 10);
      expect([bRuns, cRuns, dRuns], [2, 2, 2]);
    });

    test('no recompute when only unrelated values changed', () {
      final a = 1.obs;
      final other = 0.obs;
      var runs = 0;
      final c = Computed(() {
        runs++;
        return a.value;
      });
      expect(c.value, 1);
      other.value++;
      other.value++;
      expect(c.value, 1);
      expect(runs, 1, reason: 'its source versions did not move');
    });

    test('an unchanged intermediate result stops the update', () {
      final n = 1.obs;
      final parity = Computed(() => n.value.isEven);
      var labelRuns = 0;
      final label = Computed(() {
        labelRuns++;
        return parity.value ? 'even' : 'odd';
      });
      var notified = 0;
      label.addListener(() => notified++);
      expect(label.peek, 'odd');

      n.value = 3;
      expect(labelRuns, 1, reason: 'parity did not change');
      expect(notified, 0);
      n.value = 4;
      expect(labelRuns, 2);
      expect(notified, 1);
      expect(label.peek, 'even');
    });

    test('inside a batch: fresh on read, notified once after', () {
      final a = 1.obs;
      final b = 10.obs;
      var runs = 0;
      final sum = Computed(() {
        runs++;
        return a.value + b.value;
      });
      final seen = <int>[];
      sum.addListener(() => seen.add(sum.peek));
      expect(sum.peek, 11);

      Get.batch(() {
        a.value = 2;
        expect(sum.peek, 12, reason: 'reads see the held change');
        b.value = 20;
        expect(seen, isEmpty);
      });
      expect(seen, [22]);
      expect(runs, 3, reason: 'one run per read, none extra at the flush');
    });

    test('an error is kept until a source changes', () {
      final n = 0.obs;
      var runs = 0;
      final c = Computed(() {
        runs++;
        if (n.value < 0) throw ArgumentError('negative');
        return n.value;
      });
      n.value = -1;
      expect(() => c.value, throwsArgumentError);
      expect(() => c.value, throwsArgumentError);
      expect(runs, 1);
      n.value = 2;
      expect(c.value, 2);
      expect(runs, 2);
    });

    test('a Computed reading itself is a StateError at read', () {
      late Computed<int> c;
      c = Computed(() => c.value + 1);
      expect(() => c.value, throwsStateError);
    });

    testWidgets('an Obx on a diamond builds once with consistent values',
        (tester) async {
      final a = 1.obs;
      final b = Computed(() => a.value * 2);
      final c = Computed(() => a.value * 3);
      final shown = <String>[];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          final text = '${b.value}/${c.value}';
          shown.add(text);
          return Text(text);
        }),
      ));
      a.value = 2;
      await tester.pump();
      await tester.pump();
      expect(shown, ['2/3', '4/6']);
    });
  });

  group('source tracking', () {
    test('same reads, reordered reads, duplicates, fewer reads', () {
      final a = 1.obs, b = 2.obs, c = 3.obs;
      final mode = 0.obs;
      final sum = Computed(() {
        switch (mode.value) {
          case 0:
            return a.value + b.value + c.value;
          case 1:
            return c.value + a.value + a.value + b.value; // reordered, dup
          default:
            return a.value; // fewer
        }
      });
      sum.addListener(() {});
      expect(sum.peek, 6);
      a.value = 10;
      expect(sum.peek, 15);

      mode.value = 1;
      expect(sum.peek, 3 + 10 + 10 + 2);
      expect(a.listenersLength, 1, reason: 'a duplicate read subscribes once');
      c.value = 4;
      expect(sum.peek, 4 + 10 + 10 + 2);

      mode.value = 2;
      expect(sum.peek, 10);
      expect(b.listenersLength, 0);
      expect(c.listenersLength, 0);
      b.value = 99;
      c.value = 99;
      expect(sum.peek, 10);
      a.value = 11;
      expect(sum.peek, 11);
    });

    test('an error part-way keeps every source of the last run', () {
      final a = 1.obs, b = 2.obs;
      final fail = false.obs;
      final c = Computed(() {
        final x = a.value;
        if (fail.value) throw StateError('x');
        return x + b.value;
      });
      c.addListener(() {});
      expect(c.peek, 3);
      fail.value = true;
      expect(() => c.peek, throwsStateError);
      expect(b.listenersLength, 1, reason: 'kept: it may matter again');
      fail.value = false;
      b.value = 5;
      expect(c.peek, 6);
    });
  });

  group('effect', () {
    test('runs now and again when what it read changes', () {
      final n = 1.obs;
      final seen = <int>[];
      final e = effect(() => seen.add(n.value));
      expect(seen, [1]);
      n.value = 2;
      expect(seen, [1, 2], reason: 'synchronous');
      e.dispose();
      n.value = 3;
      expect(seen, [1, 2]);
      expect(n.listenersLength, 0);
    });

    test('once per batch', () {
      final a = 1.obs;
      final b = 2.obs;
      final seen = <int>[];
      effect(() => seen.add(a.value + b.value));
      Get.batch(() {
        a.value = 10;
        b.value = 20;
      });
      expect(seen, [3, 30]);
    });

    test('on a diamond: runs once, sees consistent values', () {
      final a = 1.obs;
      final b = Computed(() => a.value * 2);
      final d = Computed(() => b.value + a.value);
      final seen = <String>[];
      effect(() => seen.add('${a.value} ${b.value} ${d.value}'));
      a.value = 2;
      expect(seen, ['1 2 3', '2 4 6']);
    });

    test('does not run when a Computed it reads stays equal', () {
      final n = 1.obs;
      final parity = Computed(() => n.value.isEven);
      var runs = 0;
      effect(() {
        runs++;
        parity.value;
      });
      n.value = 3;
      n.value = 5;
      expect(runs, 1);
      n.value = 6;
      expect(runs, 2);
    });

    test('cleanup runs before the next run and on dispose', () {
      final room = 'a'.obs;
      final log = <String>[];
      final e = effect(() {
        final r = room.value;
        log.add('join $r');
        return () => log.add('leave $r');
      });
      room.value = 'b';
      e.dispose();
      e.dispose();
      expect(log, ['join a', 'leave a', 'join b', 'leave b']);
    });

    test('follows only what its last run read', () {
      final useA = true.obs;
      final a = 1.obs;
      final b = 2.obs;
      var runs = 0;
      effect(() {
        runs++;
        useA.value ? a.value : b.value;
      });
      useA.value = false;
      expect(a.listenersLength, 0);
      a.value = 5;
      expect(runs, 2);
      b.value = 5;
      expect(runs, 3);
    });

    test('its writes are held until it returns', () {
      final source = 0.obs;
      final x = 0.obs;
      final y = 0.obs;
      final seen = <String>[];
      x.addListener(() => seen.add('x=${x.value} y=${y.value}'));
      effect(() {
        final v = source.value;
        x.value = v;
        y.value = v;
      });
      source.value = 1;
      expect(seen, ['x=1 y=1']);
    });

    test('an effect writing what it reads is stopped', () {
      final n = 0.obs;
      expect(() => effect(() => n.value = n.value + 1), throwsStateError);
      expect(n.listenersLength, 0, reason: 'disposed');
    });

    test('a first-run error is thrown, later ones reported', () {
      expect(() => effect(() => throw StateError('first')), throwsStateError);

      final reported = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      final n = 0.obs;
      var runs = 0;
      effect(() {
        runs++;
        if (n.value == 1) throw StateError('later');
      });
      n.value = 1;
      expect(reported.single, isA<StateError>());
      n.value = 2;
      expect(runs, 3, reason: 'still follows its sources');
    });

    testWidgets('created in a build, it does not subscribe the Obx',
        (tester) async {
      final n = 0.obs;
      final shown = 'x'.obs;
      var builds = 0;
      Effect? e;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          builds++;
          e ??= effect(() => n.value);
          return Text(shown.value);
        }),
      ));
      n.value = 1;
      await tester.pump();
      await tester.pump();
      expect(builds, 1);
      e!.dispose();
    });
  });
}
