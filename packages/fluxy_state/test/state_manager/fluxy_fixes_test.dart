import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

class _IdController extends GetxController {}

class _ReadyController extends GetxController {
  int ready = 0;
  @override
  void onReady() => ready++;
}

class _Model {
  int n = 0;
}

class _Futurizer extends GetxController with StateMixin<String> {
  int notifications = 0;
  _Futurizer() {
    addListener(() => notifications++);
  }
}

void main() {
  tearDown(Get.resetInstance);

  group('Obx', () {
    testWidgets('an Rx change in the frame that unmounts it does not assert',
        (tester) async {
      final rx = 0.obs;
      await tester.pumpWidget(Obx(() => Text('${rx.value}',
          textDirection: TextDirection.ltr)));
      // Replaces the Obx; the change is made in the same frame, before the
      // Obx is unmounted, so its rebuild microtask runs after unmount.
      await tester.pumpWidget(Builder(builder: (_) {
        rx.value++;
        return const SizedBox();
      }));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('trigger with the same value rebuilds', (tester) async {
      final rx = 1.obs;
      var builds = 0;
      await tester.pumpWidget(Obx(() {
        builds++;
        return Text('${rx.value}', textDirection: TextDirection.ltr);
      }));
      rx.trigger(2); // a first change, so the next one is a "same value"
      await tester.pump();
      await tester.pump();
      expect(builds, 2);
      rx.trigger(2);
      await tester.pump();
      await tester.pump();
      expect(builds, 3);
    });
  });

  group('GetBuilder / Bind', () {
    testWidgets('follows a changed id', (tester) async {
      final controller = Get.put(_IdController());
      var builds = 0;
      Widget app(String id) => GetBuilder<_IdController>(
            id: id,
            builder: (_) {
              builds++;
              return const SizedBox();
            },
          );
      await tester.pumpWidget(app('a'));
      await tester.pumpWidget(app('b'));
      final before = builds;

      controller.update(['a']);
      await tester.pump();
      expect(builds, before, reason: 'no longer listening to the old id');

      controller.update(['b']);
      await tester.pump();
      expect(builds, before + 1);
    });

    testWidgets('Bind.put without permanent removes on unmount',
        (tester) async {
      await tester.pumpWidget(Binds(
        binds: [Bind.put(_IdController())],
        child: const SizedBox(),
      ));
      expect(Get.isRegistered<_IdController>(), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(Get.isRegistered<_IdController>(), isFalse);
    });

    testWidgets('Bind.put permanent keeps the instance', (tester) async {
      await tester.pumpWidget(Binds(
        binds: [Bind.put(_IdController(), permanent: true)],
        child: const SizedBox(),
      ));
      await tester.pumpWidget(const SizedBox());
      expect(Get.isRegistered<_IdController>(), isTrue);
    });
  });

  group('Rx', () {
    test('bindStream outside a build is cancelled on close', () async {
      var cancelled = false;
      final source = StreamController<int>(onCancel: () => cancelled = true);
      final rx = 0.obs;
      final sub = rx.bindStream(source.stream);
      expect(sub, isA<StreamSubscription<int>>());
      source.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(rx.value, 3);
      rx.close();
      expect(cancelled, isTrue);
    });

    test('listenAndPump pumps only the new subscriber', () async {
      final rx = 5.obs;
      final other = <int>[];
      final pumped = <int>[];
      rx.listen(other.add);
      rx.listenAndPump(pumped.add);
      await Future<void>.delayed(Duration.zero);
      expect(pumped, [5]);
      expect(other, isEmpty);
      rx.value = 6;
      await Future<void>.delayed(Duration.zero);
      expect(pumped, [5, 6]);
      expect(other, [6]);
    });

    test('call: rxn(null) sets null and returns the new value', () {
      final name = Rxn<String>('a');
      var calls = 0;
      name.addListener(() => calls++);
      expect(name(null), isNull);
      expect(name.value, isNull);
      expect(calls, 1);
      expect(name('b'), 'b');

      final count = 3.obs;
      expect(count(4), 4);

      final v = Value<int?>(1);
      v(null);
      expect(v.peek, isNull);
    });

    test('call: an Rx still works as a ValueChanged', () {
      final text = ''.obs;
      final ValueChanged<String> onChanged = text.call;
      onChanged('hi');
      expect(text.value, 'hi');
    });

    test('update that edits in place still notifies', () async {
      final rx = _Model().obs;
      var calls = 0;
      rx.addListener(() => calls++);
      rx.value = rx.peek; // primes firstRebuild
      calls = 0;
      rx.update((m) => m!..n = 1);
      expect(calls, 1);
      expect(rx.peek.n, 1);
    });
  });

  group('workers', () {
    test('debounce dropped on dispose does not run', () async {
      final rx = 0.obs;
      var calls = 0;
      final w = debounce(rx, (_) => calls++,
          time: const Duration(milliseconds: 20));
      rx.value = 1;
      await Future<void>.delayed(Duration.zero);
      w.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 0);
    });

    test('interval dropped on dispose does not run', () async {
      final rx = 0.obs;
      var calls = 0;
      final w = interval(rx, (_) => calls++,
          time: const Duration(milliseconds: 20));
      rx.value = 1;
      await Future<void>.delayed(Duration.zero);
      w.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 0);
    });

    test('interval still delivers when kept', () async {
      final rx = 0.obs;
      final got = <int>[];
      interval(rx, got.add, time: const Duration(milliseconds: 20));
      rx.value = 1;
      await Future<void>.delayed(Duration.zero);
      rx.value = 2; // inside the window: ignored
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(got, [1]);
    });
  });

  group('StateMixin.futurize', () {
    test('newest call wins and each result notifies once', () async {
      final c = _Futurizer();
      final slow = Completer<String>();
      final fast = Completer<String>();
      c.futurize(() => slow.future);
      c.futurize(() => fast.future);
      c.notifications = 0;

      fast.complete('new');
      await Future<void>.delayed(Duration.zero);
      expect(c.status.data, 'new');
      expect(c.notifications, 1);

      slow.complete('old');
      await Future<void>.delayed(Duration.zero);
      expect(c.status.data, 'new');
      expect(c.notifications, 1);
    });

    test('keeps the thrown error object', () async {
      final c = _Futurizer();
      final error = StateError('boom');
      c.futurize(() => Future<String>.error(error));
      await Future<void>.delayed(Duration.zero);
      expect(c.status.error, same(error));
    });
  });

  group('Computed', () {
    test('a throwing compute does not skip the source\'s other listeners',
        () {
      final src = 0.obs;
      final c = Computed(() {
        if (src.value == 1) throw StateError('bad');
        return src.value;
      });
      var computedNotified = 0;
      c.addListener(() => computedNotified++);
      expect(c.value, 0);

      var otherCalls = 0;
      src.addListener(() => otherCalls++);

      src.value = 1;
      expect(otherCalls, 1);
      expect(computedNotified, 1);
      expect(() => c.value, throwsStateError);

      src.value = 2;
      expect(c.value, 2);
    });

    test('unsubscribes from its sources when the last listener leaves', () {
      final src = 0.obs;
      final c = Computed(() => src.value * 2);
      final remove = c.addListener(() {});
      expect(c.value, 0);
      expect(src.subscribersLength, 1);

      remove();
      expect(src.subscribersLength, 0);

      src.value = 3;
      expect(c.value, 6);
    });
  });

  group('lifecycle', () {
    testWidgets('onReady is skipped when deleted before the frame',
        (tester) async {
      final c = Get.put(_ReadyController());
      Get.delete<_ReadyController>();
      await tester.pump();
      expect(c.ready, 0);
    });

    testWidgets('onReady runs after the next frame', (tester) async {
      final c = Get.put(_ReadyController());
      await tester.pump();
      expect(c.ready, 1);
    });
  });
}
