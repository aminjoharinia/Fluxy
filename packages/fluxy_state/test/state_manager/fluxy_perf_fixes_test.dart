import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_state/fluxy_state.dart';

class ListController extends GetxController with StateMixin<List<int>> {}

// An Rx is a ListNotifierSingle; refresh() notifies its listeners.
extension on RxInt {
  // ignore: invalid_use_of_protected_member
  void notify() => refresh();
}

void main() {
  group('StateMixin status', () {
    test('setSuccess with the same list edited in place notifies', () {
      final c = ListController();
      final list = <int>[1];
      c.setSuccess(list);
      var calls = 0;
      c.addListener(() => calls++);
      list.add(2);
      c.setSuccess(list);
      expect(calls, 1);
      expect(c.state, [1, 2]);
    });

    test('an unchanged non-success status still does not notify', () {
      final c = ListController();
      var calls = 0;
      c.addListener(() => calls++);
      c.setLoading(); // already loading
      expect(calls, 0);
      c.setError('x');
      c.setError('x');
      expect(calls, 1);
      c.setEmpty();
      c.setEmpty();
      expect(calls, 2);
    });
  });

  group('ListNotifier notify', () {
    test('listeners added or removed during a notify apply from the next one',
        () {
      final n = 0.obs;
      final calls = <String>[];
      late void Function() removeB;
      void c() => calls.add('c');
      n.addListener(() {
        calls.add('a');
        removeB();
        n.addListener(c);
      });
      removeB = n.addListener(() => calls.add('b'));

      n.notify();
      expect(calls, ['a', 'b'], reason: 'this round sees the old list');

      calls.clear();
      n.notify();
      // 'a' runs again and adds a second 'c', which waits for the next round.
      expect(calls, ['a', 'c']);
    });

    test('a listener that notifies again re-enters safely', () {
      final n = 0.obs;
      var depth = 0;
      var calls = 0;
      n.addListener(() {
        calls++;
        if (depth++ == 0) n.notify();
      });
      n.addListener(() => calls++);
      n.notify();
      expect(calls, 4);
      expect(n.listenersLength, 2);
    });

    test('a listener can dispose its notifier during a notify', () {
      final n = 0.obs;
      var second = 0;
      n.addListener(n.close);
      n.addListener(() => second++);
      n.notify();
      expect(second, 1);
      expect(n.isDisposed, isTrue);
    });
  });

  testWidgets('Obx: several changes before the microtask give one rebuild',
      (tester) async {
    final a = 0.obs;
    final b = 0.obs;
    var builds = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Obx(() {
        builds++;
        return Text('${a.value} ${b.value}');
      }),
    ));
    expect(builds, 1);

    a.value = 1;
    b.value = 1;
    a.value = 2;
    await tester.pump(); // runs the microtask
    await tester.pump(); // builds the frame
    expect(builds, 2);
    expect(find.text('2 1'), findsOneWidget);

    b.value = 2; // the flag was reset: later changes still rebuild
    await tester.pump(); // runs the microtask
    await tester.pump(); // builds the frame
    expect(builds, 3);
    expect(find.text('2 2'), findsOneWidget);
  });
}
