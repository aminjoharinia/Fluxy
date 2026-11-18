// FluxyScope, Dep handles and overrides (DI-PLAN.md phases 1-4).
import 'package:flutter/widgets.dart';
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

class Api {
  String get() => 'real';
}

class FakeApi extends Api {
  @override
  String get() => 'fake';
}

final counter = Dep(() => C(1), name: 'counter');
final other = Dep(() => C(2), name: 'other');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Fluxy.resetInstance);

  group('container rules', () {
    test('put of void or dynamic is rejected', () {
      expect(() => Fluxy.put<void>(C()), throwsArgumentError);
      expect(() => Fluxy.put<dynamic>(C()), throwsArgumentError);
      expect(() => Fluxy.lazyPut<Object?>(C.new), throwsArgumentError);
    });

    test('the same instance put twice is kept, not closed', () {
      final c = Fluxy.put(C());
      Fluxy.put(c);
      expect(c.closes, 0);
      expect(Fluxy.find<C>(), same(c));
    });

    test('a second lazyPut is ignored', () {
      Fluxy.lazyPut(() => C(1));
      Fluxy.lazyPut(() => C(2));
      expect(Fluxy.find<C>().n, 1);
    });

    test('spawn builds one per find', () {
      Fluxy.spawn(() => C());
      expect(identical(Fluxy.find<C>(), Fluxy.find<C>()), isFalse);
    });

    test('permanent needs force', () {
      final c = Fluxy.put(C(), permanent: true);
      expect(Fluxy.delete<C>(), isFalse);
      expect(c.closes, 0);
      expect(Fluxy.delete<C>(force: true), isTrue);
      expect(c.closes, 1);
    });

    test('reset closes newest first', () {
      final order = <int>[];
      final a = Fluxy.put(C(1), tag: 'a');
      final b = Fluxy.put(C(2), tag: 'b');
      a.onDispose(() => order.add(1));
      b.onDispose(() => order.add(2));
      Fluxy.resetInstance();
      expect(order, [2, 1]);
    });

    test('missing type: DependencyNotFound names it', () {
      expect(
        () => Fluxy.find<C>(tag: 'x'),
        throwsA(
          isA<DependencyNotFound>().having(
            (e) => e.toString(),
            'message',
            contains('"C" with tag "x" is not registered'),
          ),
        ),
      );
    });
  });

  group('scopes', () {
    test('registrations made in run() go to the scope and close with it', () {
      final scope = FluxyScope(name: 'page');
      final c = scope.run(() => Fluxy.put(C(5)));
      expect(Fluxy.find<C>(), same(c));
      expect(FluxyScope.root.local(C), isNull);
      scope.close();
      expect(c.closes, 1);
      expect(Fluxy.isRegistered<C>(), isFalse);
    });

    test('a child scope shadows the root while open', () {
      final rootC = Fluxy.put(C(1));
      final scope = FluxyScope(name: 'page');
      final pageC = scope.run(() => Fluxy.put(C(2)));
      expect(Fluxy.find<C>(), same(pageC));
      expect(scope.find<C>(), same(pageC));
      scope.close();
      expect(Fluxy.find<C>(), same(rootC));
      expect(rootC.closes, 0);
    });

    test('a scope find looks in its parents, not in sibling scopes', () {
      final a = FluxyScope(name: 'a');
      final b = FluxyScope(name: 'b');
      a.run(() => Fluxy.put(C(1)));
      expect(() => b.find<C>(), throwsA(isA<DependencyNotFound>()));
      final child = FluxyScope(name: 'child', parent: a);
      expect(child.find<C>().n, 1);
      a.close();
      b.close();
      child.close();
    });

    test('a lazy builder that puts registers in its own scope', () {
      final scope = FluxyScope(name: 'page');
      scope.run(
        () => Fluxy.lazyPut<C>(() {
          Fluxy.put(Api());
          return C();
        }),
      );
      Fluxy.find<C>();
      expect(scope.local(Api), isNotNull);
      scope.close();
      expect(Fluxy.isRegistered<Api>(), isFalse);
    });

    test('spawned instances of a scope close with it', () {
      final scope = FluxyScope(name: 'page');
      scope.run(() => Fluxy.spawn(() => C()));
      final a = Fluxy.find<C>();
      final b = Fluxy.find<C>();
      scope.close();
      expect(a.closes, 1);
      expect(b.closes, 1);
    });

    testWidgets('DependencyScope registers for its subtree', (t) async {
      final show = ValueNotifier(true);
      C? seen;
      await t.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, on, _) => on
              ? DependencyScope(
                  dependencies: () => Fluxy.lazyPut(() => C(9)),
                  child: Builder(
                    builder: (context) {
                      seen = context.find<C>();
                      return const SizedBox();
                    },
                  ),
                )
              : const SizedBox(),
        ),
      );
      expect(seen!.n, 9);
      show.value = false;
      await t.pump();
      expect(seen!.closes, 1);
      expect(Fluxy.isRegistered<C>(), isFalse);
    });
  });

  group('Dep handles', () {
    test('built on first call, kept, own key', () {
      final a = counter();
      expect(a.n, 1);
      expect(counter(), same(a));
      expect(other().n, 2);
      expect(Fluxy.isRegistered<C>(), isFalse);
    });

    test('delete keeps the builder; force removes it', () {
      final a = counter();
      counter.delete();
      expect(a.closes, 1);
      expect(counter.isRegistered, isTrue);
      expect(identical(counter(), a), isFalse);
      counter.delete(force: true);
      expect(counter.isRegistered, isFalse);
    });

    test('register in a scope gives that scope its own instance', () {
      final appWide = counter();
      final scope = FluxyScope(name: 'page');
      scope.run(counter.register);
      final pageOne = counter();
      expect(identical(pageOne, appWide), isFalse);
      scope.close();
      expect(pageOne.closes, 1);
      expect(counter(), same(appWide));
    });

    test('put replaces', () {
      final a = counter();
      final b = counter.put(C(3));
      expect(a.closes, 1);
      expect(counter(), same(b));
    });
  });

  group('overrides', () {
    test('Fluxy.overrideWith wins over the registration until reset', () {
      Fluxy.put(Api());
      Fluxy.overrideWith<Api>(FakeApi());
      expect(Fluxy.find<Api>().get(), 'fake');
      Fluxy.clearOverrides();
      expect(Fluxy.find<Api>().get(), 'real');
    });

    test('a handle override', () {
      final fake = counter.overrideWith(C(42));
      expect(counter().n, 42);
      Fluxy.resetInstance();
      expect(fake.closes, 1);
      expect(counter().n, 1);
    });
  });
}
