import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_utils/fluxy_utils.dart';

class TestClass {
  final name = "John";
}

class EmptyClass {}

void main() {
  dynamic newId(dynamic e) => e;

  test('null isNullOrBlank should be true for null', () {
    expect(FluxyUtils.isNullOrBlank(null), true);
  });

  test('isNullOrBlank should be false for unsupported types', () {
    expect(FluxyUtils.isNullOrBlank(5), false);
    expect(FluxyUtils.isNullOrBlank(0), false);

    expect(FluxyUtils.isNullOrBlank(5.0), equals(false));
    expect(FluxyUtils.isNullOrBlank(0.0), equals(false));

    TestClass? testClass;
    expect(FluxyUtils.isNullOrBlank(testClass), equals(true));
    expect(FluxyUtils.isNullOrBlank(TestClass()), equals(false));
    expect(FluxyUtils.isNullOrBlank(EmptyClass()), equals(false));
  });

  test('isNullOrBlank should validate strings', () {
    expect(FluxyUtils.isNullOrBlank(""), true);
    expect(FluxyUtils.isNullOrBlank("  "), true);

    expect(FluxyUtils.isNullOrBlank("foo"), false);
    expect(FluxyUtils.isNullOrBlank(" foo "), false);

    expect(FluxyUtils.isNullOrBlank("null"), false);
  });

  test('isNullOrBlank should validate iterables', () {
    expect(FluxyUtils.isNullOrBlank([].map(newId)), true);
    expect(FluxyUtils.isNullOrBlank([1].map(newId)), false);
  });

  test('isNullOrBlank should validate lists', () {
    expect(FluxyUtils.isNullOrBlank(const []), true);
    expect(FluxyUtils.isNullOrBlank(['oi', 'foo']), false);
    expect(FluxyUtils.isNullOrBlank([{}, {}]), false);
    expect(FluxyUtils.isNullOrBlank(['foo'][0]), false);
  });

  test('isNullOrBlank should validate sets', () {
    expect(FluxyUtils.isNullOrBlank(<dynamic>{}), true);
    expect(FluxyUtils.isNullOrBlank({1}), false);
    expect(
      FluxyUtils.isNullOrBlank({'fluorine', 'chlorine', 'bromine'}),
      false,
    );
  });

  test('isNullOrBlank should validate maps', () {
    expect(FluxyUtils.isNullOrBlank({}), true);
    expect(FluxyUtils.isNullOrBlank({1: 1}), false);
    expect(FluxyUtils.isNullOrBlank({"other": "thing"}), false);

    final map = {"foo": 'bar', "one": "um"};
    expect(FluxyUtils.isNullOrBlank(map["foo"]), false);
    expect(FluxyUtils.isNullOrBlank(map["other"]), true);
  });
  group('GetUtils.isLength* functions', () {
    test('isLengthEqualTo should validate iterable lengths', () {
      // iterables should cover list and set
      expect(FluxyUtils.isLengthEqualTo([].map(newId), 0), true);
      expect(FluxyUtils.isLengthEqualTo([1, 2].map(newId), 2), true);

      expect(FluxyUtils.isLengthEqualTo({}, 0), true);
      expect(FluxyUtils.isLengthEqualTo({1: 1, 2: 1}, 2), true);
      expect(FluxyUtils.isLengthEqualTo({}, 2), false);

      expect(FluxyUtils.isLengthEqualTo("", 0), true);
      expect(FluxyUtils.isLengthEqualTo("a", 0), false);
      expect(FluxyUtils.isLengthEqualTo("a", 1), true);
    });

    test('isLengthGreaterOrEqual should validate lengths', () {
      // iterables should cover list and set
      expect(FluxyUtils.isLengthGreaterOrEqual([].map(newId), 0), true);
      expect(FluxyUtils.isLengthGreaterOrEqual([1, 2].map(newId), 2), true);
      expect(FluxyUtils.isLengthGreaterOrEqual([1, 2].map(newId), 1), true);

      expect(FluxyUtils.isLengthGreaterOrEqual({}, 0), true);
      expect(FluxyUtils.isLengthGreaterOrEqual({1: 1, 2: 1}, 1), true);
      expect(FluxyUtils.isLengthGreaterOrEqual({1: 1, 2: 1}, 2), true);
      expect(FluxyUtils.isLengthGreaterOrEqual({}, 2), false);

      expect(FluxyUtils.isLengthGreaterOrEqual("", 0), true);
      expect(FluxyUtils.isLengthGreaterOrEqual("a", 0), true);
      expect(FluxyUtils.isLengthGreaterOrEqual("", 1), false);
    });

    test('isLengthLessOrEqual should validate lengths', () {
      // iterables should cover list and set
      expect(FluxyUtils.isLengthLessOrEqual([].map(newId), 0), true);
      expect(FluxyUtils.isLengthLessOrEqual([1, 2].map(newId), 2), true);
      expect(FluxyUtils.isLengthLessOrEqual([1, 2].map(newId), 1), false);

      expect(FluxyUtils.isLengthLessOrEqual({}, 0), true);
      expect(FluxyUtils.isLengthLessOrEqual({1: 1, 2: 1}, 1), false);
      expect(FluxyUtils.isLengthLessOrEqual({1: 1, 2: 1}, 3), true);
      expect(FluxyUtils.isLengthLessOrEqual({}, 2), true);

      expect(FluxyUtils.isLengthLessOrEqual("", 0), true);
      expect(FluxyUtils.isLengthLessOrEqual("a", 2), true);
      expect(FluxyUtils.isLengthLessOrEqual("a", 0), false);
    });
  });
}
