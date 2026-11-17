import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fluxy_nav/src/routing/nav_queue.dart';

import 'utils/stack.dart';

final table = RouteTable([
  for (final n in ['/', '/a', '/b', '/c'])
    FluxyPage(name: n, page: () => Text(n)),
]);

NavEntry e(String location) =>
    NavEntry.create<String>(match: table.match(location));

List<String> names(NavStack s) => s.entries.map((x) => x.location).toList();

void main() {
  group('NavStack', () {
    test('push / pop keeps the last entry', () {
      final s = NavStack().push(e('/')).push(e('/a'));
      expect(names(s.pop()), ['/']);
      expect(names(s.pop().pop()), ['/']);
      expect(s.canPop, isTrue);
      expect(s.pop().canPop, isFalse);
    });

    test('changes return new stacks', () {
      final s = NavStack([e('/')]);
      final t = s.push(e('/a'));
      expect(names(s), ['/']);
      expect(names(t), ['/', '/a']);
      expect(() => t.entries.add(e('/b')), throwsUnsupportedError);
    });

    test('popUntil keeps one; removeUntil may empty it', () {
      final s = NavStack([e('/'), e('/a'), e('/b')]);
      expect(names(s.popUntil((x) => x.location == '/a')), ['/', '/a']);
      expect(names(s.popUntil((_) => false)), ['/']);
      expect(names(s.removeUntil((_) => false)), isEmpty);
    });

    test('replaceTop, remove, lastAt', () {
      final a = e('/a');
      final s = NavStack([e('/'), a, e('/b')]);
      expect(names(s.replaceTop(e('/c'))), ['/', '/a', '/c']);
      expect(names(s.remove(a)), ['/', '/b']);
      expect(identical(s.lastAt('/a'), a), isTrue);
      expect(names(NavStack().replaceTop(e('/c'))), ['/c']);
    });

    group('duplicates', () {
      final base = NavStack([e('/'), e('/a'), e('/b')]);

      test('reorderRoutes moves it up under the same key', () {
        final again = e('/a');
        final s = base.add(again);
        expect(names(s), ['/', '/b', '/a']);
        expect(s.top!.key, base.entries[1].key);
        expect(s.top!.token, same(again.token));
      });

      test('recreate moves it up under a new key', () {
        final s = base.add(
          e('/a'),
          mode: PreventDuplicateHandlingMode.recreate,
        );
        expect(names(s), ['/', '/b', '/a']);
        expect(s.top!.key, isNot(base.entries[1].key));
      });

      test('popUntilOriginalRoute pops back to it', () {
        final s = base.add(
          e('/a'),
          mode: PreventDuplicateHandlingMode.popUntilOriginalRoute,
        );
        expect(names(s), ['/', '/a']);
        expect(identical(s.top, base.entries[1]), isTrue);
      });

      test('doNothing', () {
        final s = base.add(
          e('/a'),
          mode: PreventDuplicateHandlingMode.doNothing,
        );
        expect(identical(s, base), isTrue);
      });

      test('preventDuplicates: false adds a second one with its own key', () {
        final s = base.add(e('/a'), preventDuplicates: false);
        expect(names(s), ['/', '/a', '/b', '/a']);
        expect(s.top!.key, isNot(base.entries[1].key));
      });

      test('another query is another location', () {
        expect(names(base.add(e('/a?x=1'))), ['/', '/a', '/b', '/a?x=1']);
      });
    });
  });

  group('NavEntry', () {
    test('completes once, wrong types as null', () async {
      final x = e('/a');
      x.complete(5);
      expect(await x.result, isNull);
      final y = e('/a');
      y.complete('ok');
      y.complete('again');
      expect(await y.result, 'ok');
    });

    test('carries the settings and parameters', () {
      final m = RouteTable([
        FluxyPage(name: '/item/:id', page: () => const SizedBox()),
      ]).match('/item/4?tab=1');
      final x = NavEntry.create<void>(match: m, arguments: 'arg');
      expect(x.settings.params, {'id': '4', 'tab': '1'});
      expect(x.settings.arguments, 'arg');
      expect(x.key, const ValueKey('/item/4?tab=1'));
      expect(x.name, '/item/4');
    });
  });

  group('NavQueue', () {
    test('runs right away when idle', () {
      final q = NavQueue();
      var ran = false;
      final r = q.run(() {
        ran = true;
        return 1;
      });
      expect(ran, isTrue);
      expect(r, 1);
      expect(q.isIdle, isTrue);
    });

    test('later tasks wait for a pending one, in order', () async {
      final q = NavQueue();
      final gate = Completer<void>();
      final log = <String>[];
      q.run(() async {
        await gate.future;
        log.add('a');
      });
      final b = q.run(() => log.add('b'));
      expect(b, isA<Future>());
      expect(log, isEmpty);
      gate.complete();
      await b;
      expect(log, ['a', 'b']);
      expect(q.isIdle, isTrue);
    });

    test('a failing task does not block the queue', () async {
      final q = NavQueue();
      final a = q.run<void>(() async => throw StateError('x'));
      final b = q.run(() => 2);
      await expectLater(a, throwsStateError);
      expect(await b, 2);
    });
  });

  group('delegate queue', () {
    tearDown(Fluxy.reset);

    testWidgets('offAllNamed drops navigations still waiting', (t) async {
      final gate = Completer<void>();
      await t.pumpWidget(
        FluxyApp.router(
          getPages: [
            FluxyPage(name: '/', page: () => const Text('root')),
            FluxyPage(
              name: '/slow',
              page: () => const Text('slow'),
              middlewares: [_Slow(gate)],
            ),
            FluxyPage(name: '/login', page: () => const Text('login')),
          ],
        ),
      );
      await t.pumpAndSettle();
      final slow = Fluxy.toNamed('/slow');
      Fluxy.offAllNamed('/login');
      gate.complete();
      await t.pumpAndSettle();
      expect(stackNames(), ['/login']);
      expect(await slow, isNull);
    });

    testWidgets('a navigation without middleware applies before it returns', (
      t,
    ) async {
      await t.pumpWidget(
        FluxyApp.router(
          getPages: [
            FluxyPage(name: '/', page: () => const Text('root')),
            FluxyPage(name: '/a', page: () => const Text('a')),
          ],
        ),
      );
      await t.pumpAndSettle();
      Fluxy.toNamed('/a');
      expect(stackNames(), ['/', '/a']);
      Fluxy.back();
      expect(stackNames(), ['/']);
    });

    testWidgets('navigating from build waits for the frame', (t) async {
      await t.pumpWidget(
        FluxyApp.router(
          getPages: [
            FluxyPage(name: '/', page: () => _GoInBuild()),
            FluxyPage(name: '/a', page: () => const Text('a')),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
    });
  });
}

class _Slow extends FluxyMiddleware {
  _Slow(this.gate);
  final Completer<void> gate;
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    await gate.future;
    return route;
  }
}

class _GoInBuild extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Fluxy.currentRoute != '/a') Fluxy.offAllNamed('/a');
    return const Text('root');
  }
}
