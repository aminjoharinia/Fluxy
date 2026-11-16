import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

/// Collects what [FlutterError.reportError] receives during the test.
List<Object> _captureReported() {
  final reported = <Object>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => reported.add(details.exception);
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}

void main() {
  group('a throwing listener', () {
    test('is reported; the other listeners still run; the write succeeds',
        () {
      final reported = _captureReported();
      final n = 0.obs;
      final seen = <String>[];
      n.addListener(() => seen.add('first'));
      n.addListener(() => throw StateError('broken listener'));
      n.addListener(() => seen.add('third'));

      n.value = 1; // does not throw into the writer
      expect(seen, ['first', 'third']);
      expect(reported.single, isA<StateError>());
      expect(n.value, 1);
    });

    test('inside a batch: the other notifiers still go out', () {
      final reported = _captureReported();
      final a = 0.obs;
      final b = 0.obs;
      var bCalls = 0;
      a.addListener(() => throw StateError('a'));
      b.addListener(() => bCalls++);

      Fluxy.batch(() {
        a.value = 1;
        b.value = 1;
      });
      expect(bCalls, 1);
      expect(reported, hasLength(1));
    });

    test('does not stop a Computed or an effect downstream', () {
      final reported = _captureReported();
      final n = 1.obs;
      n.addListener(() => throw StateError('early listener'));
      final doubled = Computed(() => n.value * 2);
      final seen = <int>[];
      final e = effect(() => seen.add(doubled.value));

      n.value = 2;
      expect(seen, [2, 4]);
      expect(reported, hasLength(1));
      e.dispose();
      doubled.dispose();
    });
  });

  group('writing a closed Rx', () {
    test('throws in debug builds', () {
      final n = 0.obs..close();
      expect(() => n.value = 1, throwsFlutterError);
      expect(() => n(1), throwsFlutterError);
      expect(() => n.update((v) => 2), throwsFlutterError);
      expect(() => n.trigger(3), throwsFlutterError);
      expect(n.peek, 0, reason: 'the write was not applied');
    });

    test('the message names the type and the fix', () {
      final name = 'a'.obs..close();
      try {
        name.value = 'b';
        fail('expected a FlutterError');
      } on FlutterError catch (e) {
        expect(e.message, contains('RxString was given a value after close()'));
        expect(e.toString(), contains('isDisposed'));
      }
    });
  });
}
