import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

void main() {
  test('ever runs synchronously, with no stream behind it', () {
    final n = 0.obs;
    final seen = <int>[];
    final w = ever(n, seen.add);
    n.value = 1;
    n.value = 2;
    expect(seen, [1, 2], reason: 'no microtask needed');
    w.dispose();
    n.value = 3;
    expect(seen, [1, 2]);
    expect(n.listenersLength, 0);
  });

  test('ever inside a batch: once, with the final value', () {
    final n = 0.obs;
    final seen = <int>[];
    ever(n, seen.add);
    Fluxy.batch(() {
      n.value = 1;
      n.value = 2;
    });
    expect(seen, [2]);
  });

  test('once fires a single time and unsubscribes', () {
    final n = 0.obs;
    final seen = <int>[];
    final w = once(n, seen.add);
    n.value = 1;
    n.value = 2;
    expect(seen, [1]);
    expect(w.disposed, isTrue);
    expect(n.listenersLength, 0);
  });

  test('everAll follows every Rx', () {
    final a = 0.obs;
    final b = ''.obs;
    final seen = <Object?>[];
    final w = everAll([a, b], seen.add);
    a.value = 1;
    b.value = 'x';
    expect(seen, [1, 'x']);
    w.dispose();
    expect(a.listenersLength + b.listenersLength, 0);
  });

  test('onError still uses the stream (errors only travel there)', () async {
    final n = 0.obs;
    final errors = <Object>[];
    ever(n, (_) {}, onError: (Object e) => errors.add(e));
    n.addError(StateError('x'));
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<StateError>());
  });
}
