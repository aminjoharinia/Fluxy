// Registry bugs from DI-PLAN.md (B2-B5, B8), skipped until fixed.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

class C extends FluxyController {
  C([this.n = 0]);
  final int n;
  int closes = 0;
  @override
  void onClose() {
    closes++;
    super.onClose();
  }
}

class S extends FluxyService {
  int closes = 0;
  @override
  void onClose() => closes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Fluxy.resetInstance);

  test('B2: put of a registered type replaces it', () {
    final a = Fluxy.put(C(1));
    final b = Fluxy.put(C(2));
    expect(b.n, 2);
    expect(Fluxy.find<C>(), same(b));
    expect(a.closes, 1);
    expect(b.initialized, isTrue);
  }, skip: true); // B2

  test('B3: replace works for services', () {
    final s1 = Fluxy.put(S());
    final s2 = S();
    Fluxy.replace<S>(s2);
    expect(Fluxy.find<S>(), same(s2));
    expect(s1.closes, 1);
  }, skip: true); // B3

  test('B4: reset closes every instance', () {
    final c = Fluxy.put(C());
    final s = Fluxy.put(S());
    Fluxy.resetInstance();
    expect(c.closes, 1);
    expect(s.closes, 1);
    expect(Fluxy.isRegistered<C>(), isFalse);
  }, skip: true); // B4

  test('B5: reload closes the old instance and builds a new one', () {
    Fluxy.lazyPut(() => C(7));
    final a = Fluxy.find<C>();
    Fluxy.reload<C>();
    final b = Fluxy.find<C>();
    expect(a.closes, 1);
    expect(identical(a, b), isFalse);
    expect(b.initialized, isTrue);
  }, skip: true); // B5

  test('B8: a missing type is a FlutterError', () {
    expect(() => Fluxy.find<C>(), throwsA(isA<FlutterError>()));
  }, skip: true); // B8
}
