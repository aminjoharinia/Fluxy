import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';

class Point with Equality {
  Point(this.x, this.y, [this.tags = const []]);
  final int x;
  final int y;
  final List<Object?> tags;

  @override
  List get props => [x, y, tags];
}

class OtherPoint with Equality {
  OtherPoint(this.x, this.y);
  final int x;
  final int y;

  @override
  List get props => [x, y, const []];
}

void main() {
  group('Equality mixin', () {
    test('equal props are equal, with equal hash codes', () {
      expect(Point(1, 2), Point(1, 2));
      expect(Point(1, 2).hashCode, Point(1, 2).hashCode);
      expect(Point(1, 2), isNot(Point(2, 1)));
    });

    test('compares nested collections deeply', () {
      final a = Point(1, 2, [
        [1, 2],
        {'k': {1, 2}},
      ]);
      final b = Point(1, 2, [
        [1, 2],
        {'k': {2, 1}},
      ]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
          a,
          isNot(Point(1, 2, [
            [2, 1],
            {'k': {1, 2}},
          ])));
    });

    test('different runtime types are never equal', () {
      expect(Point(1, 2) == OtherPoint(1, 2) as Object, isFalse);
    });
  });

  group('collection equalities', () {
    test('ListEquality is ordered', () {
      const eq = ListEquality<int>();
      expect(eq.equals([1, 2], [1, 2]), isTrue);
      expect(eq.equals([1, 2], [2, 1]), isFalse);
      expect(eq.equals([1], [1, 1]), isFalse);
      expect(eq.equals(null, null), isTrue);
      expect(eq.equals([1], null), isFalse);
      expect(eq.hash([1, 2]), eq.hash([1, 2]));
    });

    test('SetEquality and UnorderedIterableEquality ignore order', () {
      const set = SetEquality<int>();
      expect(set.equals({1, 2}, {2, 1}), isTrue);
      expect(set.equals({1, 2}, {1, 3}), isFalse);
      expect(set.hash({1, 2}), set.hash({2, 1}));

      const unordered = UnorderedIterableEquality<int>();
      expect(unordered.equals([1, 2, 2], [2, 1, 2]), isTrue);
      expect(unordered.equals([1, 2, 2], [1, 1, 2]), isFalse);
    });

    test('MapEquality compares keys and values', () {
      const eq = MapEquality<String, int>();
      expect(eq.equals({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isTrue);
      expect(eq.equals({'a': 1}, {'a': 2}), isFalse);
      expect(eq.equals({'a': 1}, {'b': 1}), isFalse);
      expect(eq.hash({'a': 1, 'b': 2}), eq.hash({'b': 2, 'a': 1}));
    });

    test('IterableEquality is ordered', () {
      const eq = IterableEquality<int>();
      expect(eq.equals([1, 2].map((e) => e), [1, 2]), isTrue);
      expect(eq.equals([1, 2], [2, 1]), isFalse);
    });

    test('IdentityEquality compares identity only', () {
      const eq = IdentityEquality<List<int>>();
      final list = [1];
      expect(eq.equals(list, list), isTrue);
      expect(eq.equals(list, [1]), isFalse);
    });

    test('DeepCollectionEquality handles mixed nesting', () {
      const eq = DeepCollectionEquality();
      expect(
          eq.equals({
            'a': [1, {2}]
          }, {
            'a': [1, {2}]
          }),
          isTrue);
      expect(eq.equals([1], {1}), isFalse);
      expect(eq.equals(1, 1), isTrue);
      expect(eq.isValidKey([1]), isTrue);
    });
  });

  group('Get singleton', () {
    test('defaults', () {
      expect(Get.smartManagement, SmartManagement.full);
      expect(Get.isLogEnable, kDebugMode);
    });

    test('log goes to the configured writer', () {
      final lines = <(String, bool)>[];
      final previous = Get.log;
      Get.log = (text, {bool isError = false}) => lines.add((text, isError));
      addTearDown(() => Get.log = previous);

      Get.log('hello');
      Get.log('bad', isError: true);
      expect(lines, [('hello', false), ('bad', true)]);
    });

    test('the default writer accepts both kinds of lines', () {
      defaultLogWriterCallback('info');
      defaultLogWriterCallback('error', isError: true);
    });

    test('toEnd runs after the current event', () async {
      final order = <String>[];
      final done = Get.toEnd(() => order.add('later'));
      order.add('now');
      await done;
      expect(order, ['now', 'later']);
    });

    test('asap runs now when the condition holds, later otherwise', () async {
      final order = <String>[];
      final now = Get.asap(() => order.add('sync'), condition: () => true);
      order.add('after sync');
      await now;
      final later = Get.asap(() => order.add('async'));
      order.add('after async');
      await later;
      expect(order, ['sync', 'after sync', 'after async', 'async']);
    });

    test('asap returns the computed value', () async {
      expect(await Get.asap(() => 42), 42);
      expect(await Get.toEnd(() => 'x'), 'x');
    });
  });

  test('Engine.instance is the widgets binding', () {
    expect(Engine.instance, same(WidgetsBinding.instance));
  });
}
