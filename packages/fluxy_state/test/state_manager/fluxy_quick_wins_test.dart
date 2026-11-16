import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

/// Counts how often `==` is called on it.
class _Counted {
  _Counted(this.n);
  final int n;
  static int compares = 0;

  @override
  bool operator ==(Object other) {
    compares++;
    return other is _Counted && other.n == n;
  }

  @override
  int get hashCode => n;
}

class _Model {
  int n = 0;
}

class _Listener {
  int calls = 0;
  void onChange() => calls++;
}

class _Controller extends GetxController {}

void main() {
  group('Rx write', () {
    test('compares the new value once', () {
      final rx = _Counted(1).obs;
      _Counted.compares = 0;
      rx.value = _Counted(2);
      expect(_Counted.compares, 1);
      _Counted.compares = 0;
      rx.value = _Counted(2); // equal: no notify, still one compare
      expect(_Counted.compares, 1);
    });

    test('an equal value never notifies, the first write included', () {
      final rx = 0.obs;
      var calls = 0;
      rx.addListener(() => calls++);
      rx.value = 0;
      expect(calls, 0);
      rx.value = 1;
      expect(calls, 1);
    });

    test('update that edits in place notifies on the very first write', () {
      final rx = _Model().obs;
      var calls = 0;
      rx.addListener(() => calls++);
      rx.update((m) => m!..n = 1);
      expect(calls, 1);
      expect(rx.peek.n, 1);
    });

    test('trigger notifies with the same value and sets a new one', () {
      final rx = 3.obs;
      var calls = 0;
      rx.addListener(() => calls++);
      rx.trigger(3);
      expect(calls, 1);
      rx.trigger(4);
      expect(calls, 2);
      expect(rx.peek, 4);
    });
  });

  group('listeners', () {
    test('a value with no listener allocates none and still notifies later',
        () {
      final rx = 0.obs;
      rx.value = 1; // nothing listens: nothing to call
      expect(rx.listenersLength, 0);
      var calls = 0;
      final remove = rx.addListener(() => calls++);
      rx.value = 2;
      expect(calls, 1);
      remove();
      remove(); // a second remove is harmless
      expect(rx.listenersLength, 0);
      rx.close();
      expect(rx.isDisposed, isTrue);
    });

    test('removeListener with a tear-off made again still removes it', () {
      final rx = 0.obs;
      final l = _Listener();
      rx.addListener(l.onChange);
      rx.removeListener(l.onChange); // a new tear-off object, == to the first
      rx.value = 1;
      expect(l.calls, 0);
      expect(rx.listenersLength, 0);
    });

    test('unsubscribing in any order removes exactly those listeners', () {
      final rx = 0.obs;
      final calls = List<int>.filled(50, 0);
      final removers = [
        for (var i = 0; i < 50; i++) rx.addListener(() => calls[i]++)
      ];
      for (var i = 49; i >= 0; i -= 2) {
        removers[i]();
      }
      rx.value = 1;
      for (var i = 0; i < 50; i++) {
        expect(calls[i], i.isEven ? 1 : 0, reason: 'listener $i');
      }
    });

    test('the same listener added twice is removed one at a time', () {
      final rx = 0.obs;
      var calls = 0;
      void listener() => calls++;
      final r1 = rx.addListener(listener);
      rx.addListener(listener);
      r1();
      rx.value = 1;
      expect(calls, 1);
    });

    test('a controller without ids disposes cleanly; ids still work', () {
      final plain = _Controller();
      plain.dispose();
      expect(plain.isDisposed, isTrue);

      final c = _Controller();
      var calls = 0;
      c.addListenerId('a', () => calls++);
      expect(c.containsId('a'), isTrue);
      c.update(['a']);
      c.update(['b']); // unknown id: nothing
      expect(calls, 1);
      c.dispose();
      expect(c.containsId('a'), isFalse);
    });
  });

  group('Get.find', () {
    tearDown(Get.resetInstance);

    test('finds, starts lazy instances once, and reports missing ones', () {
      var built = 0;
      Get.lazyPut(() {
        built++;
        return _Controller();
      });
      final a = Get.find<_Controller>();
      final b = Get.find<_Controller>();
      expect(identical(a, b), isTrue);
      expect(built, 1);
      expect(a.initialized, isTrue);
      expect(() => Get.find<_Listener>(), throwsA(contains('not found')));
      expect(Get.findOrNull<_Listener>(), isNull);
      expect(Get.findOrNull<_Controller>(), same(a));
    });

    test('tagged instances and Get.spawn', () {
      Get.put(_Controller(), tag: 'x');
      expect(Get.find<_Controller>(tag: 'x'), isA<_Controller>());
      expect(() => Get.find<_Controller>(), throwsA(anything));
      Get.spawn(() => _Listener());
      expect(identical(Get.find<_Listener>(), Get.find<_Listener>()), isFalse);
    });
  });
}
