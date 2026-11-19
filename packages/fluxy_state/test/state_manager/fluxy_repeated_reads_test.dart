import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension on WidgetTester {
  // Obx marks itself dirty in a microtask, so it takes two pumps.
  Future<void> rebuild() async {
    await pump();
    await pump();
  }
}

// The same source read many times in a row (a loop over an RxList's items)
// is recorded once, and RxList / RxMap read methods read the collection once.
void main() {
  group('repeated reads of one source', () {
    test('a loop over a list, with other sources before and after', () {
      final items = RxList<int>([1, 2, 3]);
      final a = 10.obs, b = 100.obs;
      var runs = 0;
      final sum = Computed(() {
        runs++;
        var s = a.value;
        for (var i = 0; i < items.length; i++) {
          s += items[i];
        }
        return s + b.value;
      });
      sum.addListener(() {});
      expect(sum.value, 116);

      items.add(4);
      expect(sum.value, 120);
      a.value = 20;
      expect(sum.value, 130);
      b.value = 200;
      expect(sum.value, 230);
      expect(runs, 4);
    });

    test('A A B on one run, B A A on the next: both kept', () {
      final a = 1.obs, b = 2.obs;
      final flip = false.obs;
      var runs = 0;
      final v = Computed(() {
        runs++;
        if (flip.value) return b.value + a.value + a.value;
        return a.value + a.value + b.value;
      });
      v.addListener(() {});
      expect(v.value, 4);
      flip.value = true;
      expect(v.value, 4);
      final before = runs;
      a.value = 5;
      expect(v.value, 12);
      b.value = 7;
      expect(v.value, 17);
      expect(runs, before + 2);
    });

    test('a source read repeatedly is dropped once no longer read', () {
      final items = RxList<int>([1, 2]);
      final useItems = true.obs;
      var runs = 0;
      final v = Computed(() {
        runs++;
        if (!useItems.value) return 0;
        return items[0] + items[1] + items[0];
      });
      v.addListener(() {});
      expect(v.value, 4);
      useItems.value = false;
      expect(v.value, 0);
      final before = runs;
      items.add(3);
      expect(v.value, 0);
      expect(runs, before);
    });

    testWidgets('Obx looping over an RxList rebuilds on any change',
        (tester) async {
      final items = RxList<int>([1, 2, 3]);
      final label = 'sum'.obs;
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() {
          builds++;
          var s = 0;
          for (var i = 0; i < items.length; i++) {
            s += items[i];
          }
          return Text('${label.value} $s');
        }),
      ));
      expect(find.text('sum 6'), findsOneWidget);

      items[0] = 10;
      await tester.rebuild();
      expect(find.text('sum 15'), findsOneWidget);
      label.value = 'total';
      await tester.rebuild();
      expect(find.text('total 15'), findsOneWidget);
      expect(builds, 3);
    });
  });

  group('RxList read methods', () {
    test('give the same results as the plain list', () {
      final plain = [3, 1, 4, 1, 5, 9, 2, 6];
      final rx = RxList<int>(List.of(plain));
      expect(rx.isEmpty, plain.isEmpty);
      expect(rx.isNotEmpty, plain.isNotEmpty);
      expect(rx.first, plain.first);
      expect(rx.last, plain.last);
      expect(rx.elementAt(2), plain.elementAt(2));
      expect(rx.any((e) => e > 8), isTrue);
      expect(rx.every((e) => e > 0), isTrue);
      expect(rx.contains(5), isTrue);
      expect(rx.contains('5'), isFalse);
      expect(rx.indexOf(1), 1);
      expect(rx.indexOf(1, 2), 3);
      expect(rx.indexOf('x'), -1);
      expect(rx.lastIndexOf(1), 3);
      expect(rx.lastIndexOf('x'), -1);
      expect(rx.indexWhere((e) => e > 4), 4);
      expect(rx.lastIndexWhere((e) => e > 4), 7);
      expect(rx.firstWhere((e) => e > 3), 4);
      expect(rx.firstWhere((e) => e > 100, orElse: () => -1), -1);
      expect(rx.lastWhere((e) => e < 3), 2);
      expect(rx.singleWhere((e) => e == 9), 9);
      expect(rx.fold<int>(0, (a, e) => a + e), 31);
      expect(rx.reduce((a, e) => a > e ? a : e), 9);
      expect(rx.join(','), plain.join(','));
      expect(rx.map((e) => e * 2).toList(), plain.map((e) => e * 2).toList());
      expect(rx.expand((e) => [e, e]).length, 16);
      expect(rx.skip(6).toList(), [2, 6]);
      expect(rx.take(2).toList(), [3, 1]);
      expect(rx.skipWhile((e) => e != 9).toList(), [9, 2, 6]);
      expect(rx.takeWhile((e) => e != 5).toList(), [3, 1, 4, 1]);
      expect(rx.getRange(1, 3).toList(), [1, 4]);
      expect(rx.sublist(5), [9, 2, 6]);
      expect(rx.toList(), plain);
      expect(rx.toSet(), plain.toSet());
      final seen = <int>[];
      rx.forEach(seen.add);
      expect(seen, plain);
      expect(() => RxList<int>().first, throwsStateError);
      expect(() => rx.single, throwsStateError);
    });

    test('copies are independent of the list', () {
      final rx = RxList<int>([1, 2, 3]);
      final copy = rx.toList()..add(4);
      final part = rx.sublist(0, 2)..add(9);
      expect(rx, [1, 2, 3]);
      expect(copy, [1, 2, 3, 4]);
      expect(part, [1, 2, 9]);
    });

    test('each one subscribes a Computed', () {
      final rx = RxList<int>([1, 2, 3]);
      final reads = <String, int Function()>{
        'fold': () => rx.fold(0, (a, e) => a + e),
        'any': () => rx.any((e) => e > 3) ? 1 : 0,
        'contains': () => rx.contains(4) ? 1 : 0,
        'indexOf': () => rx.indexOf(4),
        'firstWhere': () => rx.firstWhere((e) => e > 3, orElse: () => 0),
        'map': () => rx.map((e) => e).length,
        'toList': () => rx.toList().length,
        'isEmpty': () => rx.isEmpty ? 0 : rx.length,
        'last': () => rx.last,
      };
      for (final MapEntry(:key, value: read) in reads.entries) {
        final before = read();
        final c = Computed(read);
        c.addListener(() {});
        expect(c.value, before, reason: key);
        rx.add(4);
        expect(c.value, read(), reason: key);
        expect(c.value, isNot(before), reason: key);
        rx.removeLast();
        c.dispose();
      }
    });

    test('writes through cast still notify', () {
      final rx = RxList<num>([1, 2]);
      var calls = 0;
      rx.addListener(() => calls++);
      rx.cast<num>()[0] = 5;
      expect(rx.peek, [5, 2]);
      expect(calls, greaterThan(0));
    });
  });

  group('RxMap read methods', () {
    test('give the same results as the plain map', () {
      final plain = {'a': 1, 'b': 2, 'c': 3};
      final rx = RxMap<String, int>(Map.of(plain));
      expect(rx.length, 3);
      expect(rx.isEmpty, isFalse);
      expect(rx.isNotEmpty, isTrue);
      expect(rx.containsKey('b'), isTrue);
      expect(rx.containsKey('z'), isFalse);
      expect(rx.containsValue(3), isTrue);
      expect(rx.containsValue(9), isFalse);
      expect(rx.values.toList(), [1, 2, 3]);
      expect(rx.entries.map((e) => '${e.key}${e.value}').join(), 'a1b2c3');
      expect(rx.map((k, v) => MapEntry(v, k)), {1: 'a', 2: 'b', 3: 'c'});
      final seen = <String>[];
      rx.forEach((k, v) => seen.add('$k$v'));
      expect(seen, ['a1', 'b2', 'c3']);
    });

    test('each one subscribes a Computed', () {
      final rx = RxMap<String, int>({'a': 1});
      final reads = <String, int Function()>{
        'length': () => rx.length,
        'values': () => rx.values.fold(0, (a, e) => a + e),
        'entries': () => rx.entries.length,
        'containsKey': () => rx.containsKey('b') ? 1 : 0,
        'containsValue': () => rx.containsValue(2) ? 1 : 0,
        'isEmpty': () => rx.isEmpty ? 0 : rx.length,
        'forEach': () {
          var s = 0;
          rx.forEach((_, v) => s += v);
          return s;
        },
      };
      for (final MapEntry(:key, value: read) in reads.entries) {
        final c = Computed(read);
        c.addListener(() {});
        final before = c.value;
        rx['b'] = 2;
        expect(c.value, isNot(before), reason: key);
        rx.remove('b');
        expect(c.value, before, reason: key);
        c.dispose();
      }
    });
  });
}
