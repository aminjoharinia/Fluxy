import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// Obx marks itself dirty in a microtask, so a change needs two pumps to
/// show up: one to run the microtask, one to build.
extension on WidgetTester {
  Future<void> rebuild() async {
    await pump();
    await pump();
  }
}

void main() {
  group('Obx subscriptions follow what the last build read', () {
    testWidgets('a branch that is no longer read stops rebuilding the Obx',
        (tester) async {
      final showA = true.obs;
      final a = 0.obs;
      final b = 0.obs;
      var builds = 0;
      await tester.pumpWidget(_host(Obx(() {
        builds++;
        return Text(showA.value ? 'a${a.value}' : 'b${b.value}');
      })));
      expect(builds, 1);
      expect(a.listenersLength, 1);
      expect(b.listenersLength, 0);

      showA.value = false;
      await tester.rebuild();
      expect(builds, 2);
      expect(a.listenersLength, 0, reason: 'a is no longer read');
      expect(b.listenersLength, 1);

      a.value++;
      await tester.rebuild();
      expect(builds, 2, reason: 'changing an unread Rx must not rebuild');

      b.value++;
      await tester.rebuild();
      expect(builds, 3);
      expect(find.text('b1'), findsOneWidget);
    });

    testWidgets('an Rx read on every build keeps exactly one subscription',
        (tester) async {
      final a = 0.obs;
      await tester.pumpWidget(_host(Obx(() => Text('${a.value} ${a.value}'))));
      for (var i = 0; i < 5; i++) {
        a.value++;
        await tester.rebuild();
      }
      expect(a.listenersLength, 1);
      expect(find.text('5 5'), findsOneWidget);
    });

    testWidgets('unmount removes every subscription', (tester) async {
      final a = 0.obs;
      await tester.pumpWidget(_host(Obx(() => Text('${a.value}'))));
      expect(a.listenersLength, 1);
      await tester.pumpWidget(_host(const SizedBox()));
      expect(a.listenersLength, 0);
    });

    testWidgets('GetX<T> widget prunes the same way', (tester) async {
      final showA = true.obs;
      final a = 0.obs;
      final b = 0.obs;
      await tester.pumpWidget(_host(GetX<_Ctrl>(
        init: _Ctrl(),
        builder: (_) => Text(showA.value ? '${a.value}' : '${b.value}'),
      )));
      showA.value = false;
      await tester.rebuild();
      expect(a.listenersLength, 0);
      expect(b.listenersLength, 1);
      Get.resetInstance();
    });
  });

  group('peek / untrack / writes do not subscribe', () {
    testWidgets('peek and Get.untrack read without subscribing',
        (tester) async {
      final tracked = 0.obs;
      final peeked = 0.obs;
      final untracked = 0.obs;
      var builds = 0;
      await tester.pumpWidget(_host(Obx(() {
        builds++;
        final u = Get.untrack(() => untracked.value);
        return Text('${tracked.value} ${peeked.peek} $u');
      })));
      expect(peeked.listenersLength, 0);
      expect(untracked.listenersLength, 0);

      peeked.value++;
      untracked.value++;
      await tester.rebuild();
      expect(builds, 1);
    });

    testWidgets('writing an Rx inside a build does not subscribe to it',
        (tester) async {
      final source = 1.obs;
      final count = 0.obs;
      final flag = false.obs;
      final list = <int>[].obs;
      await tester.pumpWidget(_host(Obx(() {
        final v = source.value;
        count.value = v; // setter compares with peek
        count + 1; // RxInt + reads with peek
        flag.toggle();
        list.add(v);
        return Text('$v');
      })));
      expect(source.listenersLength, 1);
      expect(count.listenersLength, 0);
      expect(flag.listenersLength, 0);
      expect(list.listenersLength, 0);
    });
  });

  group('Get.batch', () {
    test('each changed Rx notifies once, with its final value', () {
      final a = 0.obs;
      final b = 0.obs;
      final seenA = <int>[];
      var bCalls = 0;
      a.addListener(() => seenA.add(a.peek));
      b.addListener(() => bCalls++);

      Get.batch(() {
        a.value = 1;
        a.value = 2;
        b.value = 5;
        expect(seenA, isEmpty, reason: 'nothing goes out inside the batch');
      });
      expect(seenA, [2]);
      expect(bCalls, 1);
    });

    test('nested batches notify when the outermost one ends', () {
      final a = 0.obs;
      var calls = 0;
      a.addListener(() => calls++);
      Get.batch(() {
        Get.batch(() => a.value = 1);
        expect(calls, 0);
        a.value = 2;
      });
      expect(calls, 1);
      expect(Get.isBatching, isFalse);
    });

    test('changes made before an exception are still notified', () {
      final a = 0.obs;
      var calls = 0;
      a.addListener(() => calls++);
      expect(
          () => Get.batch(() {
                a.value = 1;
                throw StateError('boom');
              }),
          throwsStateError);
      expect(calls, 1);
      expect(Get.isBatching, isFalse);
    });

    test('ever sees one call per batch', () async {
      final a = 0.obs;
      final values = <int>[];
      ever<int>(a, values.add);
      Get.batch(() {
        a.value = 1;
        a.value = 2;
        a.value = 3;
      });
      await Future<void>.delayed(Duration.zero);
      expect(values, [3]);
    });

    test('returns the value of the block', () {
      expect(Get.batch(() => 42), 42);
    });
  });

  group('collections notify once per call', () {
    int calls(RxInterface rx, void Function() body) {
      var n = 0;
      final dispose = (rx as dynamic).addListener(() => n++) as void Function();
      body();
      dispose();
      return n;
    }

    test('RxList bulk operations', () {
      final list = <int>[1, 2, 3, 4, 5].obs;
      expect(calls(list, () => list.insert(0, 0)), 1);
      expect(calls(list, () => list.removeAt(0)), 1);
      expect(calls(list, () => list.removeLast()), 1);
      expect(calls(list, () => list.removeRange(0, 2)), 1);
      expect(calls(list, () => list.replaceRange(0, 1, [7, 8])), 1);
      expect(calls(list, () => list.setAll(0, [1, 2])), 1);
      expect(calls(list, () => list.fillRange(0, 2, 9)), 1);
      expect(calls(list, () => list.assignAll([1, 2, 3])), 1);
      expect(list, [1, 2, 3]);
    });

    test('RxList.addAll / insertAll with itself', () {
      final list = <int>[1, 2].obs;
      list.addAll(list);
      expect(list, [1, 2, 1, 2]);
      list.insertAll(0, list);
      expect(list.length, 8);
      list.assignAll(list);
      expect(list.length, 8);
    });

    test('RxMap bulk operations', () {
      final map = <String, int>{'a': 1}.obs;
      expect(calls(map, () => map.addAll({'b': 2, 'c': 3, 'd': 4})), 1);
      expect(calls(map, () => map.updateAll((k, v) => v * 10)), 1);
      expect(calls(map, () => map.removeWhere((k, v) => v > 20)), 1);
      expect(calls(map, () => map.addEntries([MapEntry('x', 1)])), 1);
      expect(calls(map, () => map.update('x', (v) => v + 1)), 1);
      expect(calls(map, () => map.putIfAbsent('x', () => 0)), 0);
      expect(calls(map, () => map.putIfAbsent('y', () => 0)), 1);
      expect(map, {'a': 10, 'b': 20, 'x': 2, 'y': 0});
      map.addAll(map);
      expect(map.length, 4);
    });

    test('RxMap.assignAll notifies once', () {
      final map = <String, int>{'a': 1}.obs;
      expect(calls(map, () => map.assignAll({'b': 2})), 1);
      expect(map, {'b': 2});
    });

    test('RxSet operations', () {
      final set = <int>{1, 2, 3}.obs;
      expect(calls(set, () => set.assignAll([4, 5])), 1);
      expect(calls(set, () => set.removeWhere((e) => e == 4)), 1);
      set.addAll(set);
      expect(set, {5});
    });
  });

  test('RxnDouble - subtracts (upstream added)', () {
    final d = RxnDouble(10);
    d - 3;
    expect(d.value, 7);
  });
}

class _Ctrl extends GetxController {}
