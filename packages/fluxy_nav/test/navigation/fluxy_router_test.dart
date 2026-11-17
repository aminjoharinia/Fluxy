import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

List<FluxyPage> _pages() => [
      FluxyPage(name: '/', page: () => const Text('root')),
      FluxyPage(name: '/Home', page: () => const Text('home')),
      FluxyPage(name: '/Landing', page: () => const Text('landing')),
    ];

final _unknown = FluxyPage(name: '/NotFound', page: () => const Text('unknown'));

void main() {
  tearDown(Fluxy.reset);

  group('route matching', () {
    test('only a route for the whole path matches', () {
      final d = FluxyDelegate(pages: _pages(), notFoundRoute: _unknown);
      expect(d.matchRoute('/Home').route?.name, '/Home');
      expect(d.matchRoute('/Home/').route?.name, '/Home');
      expect(d.matchRoute('/Home?tab=2').route?.name, '/Home');
      expect(d.matchRoute('/').route?.name, '/');
      expect(d.matchRoute('/nope').route, isNull,
          reason: 'used to match its parent "/"');
      expect(d.matchRoute('/Home/x').route, isNull,
          reason: 'used to match its parent "/Home"');
    });

    test('path parameters still match', () {
      final d = FluxyDelegate(pages: [
        FluxyPage(name: '/', page: () => const SizedBox()),
        FluxyPage(name: '/item/:id', page: () => const SizedBox()),
      ]);
      final m = d.matchRoute('/item/42');
      expect(m.route?.name, '/item/42');
      expect(m.route?.parameters?['id'], '42');
    });

    testWidgets('an unknown address opens the unknown route', (tester) async {
      await tester.pumpWidget(FluxyApp.router(
        getPages: _pages(),
        unknownRoute: _unknown,
      ));
      await tester.pumpAndSettle();
      Fluxy.toNamed('/nope');
      await tester.pumpAndSettle();
      expect(find.text('unknown'), findsOneWidget);
    });
  });

  group('initialRoute', () {
    testWidgets('an explicit initialRoute wins over a registered "/"',
        (tester) async {
      await tester.pumpWidget(FluxyApp.router(
        getPages: _pages(),
        initialRoute: '/Landing',
      ));
      await tester.pumpAndSettle();
      expect(find.text('landing'), findsOneWidget);
    });

    testWidgets('without one, "/" opens its own page', (tester) async {
      await tester.pumpWidget(FluxyApp.router(getPages: _pages()));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    test('parser: redirect only when asked or when "/" is no page', () {
      final redirect = FluxyInformationParser(
          initialRoute: '/Landing', redirectRootToInitialRoute: true);
      final plain = FluxyInformationParser(initialRoute: '/Landing');
      expect(redirect.redirectRootToInitialRoute, isTrue);
      expect(plain.redirectRootToInitialRoute, isFalse);
    });
  });

  group('routing state', () {
    testWidgets('an app-provided delegate keeps Get.routing current, with '
        'no observer', (tester) async {
      final delegate = FluxyDelegate(pages: _pages());
      await tester.pumpWidget(FluxyApp.router(
        getPages: _pages(),
        routerDelegate: delegate,
      ));
      await tester.pumpAndSettle();

      Fluxy.dialog(const Text('dialog'));
      await tester.pumpAndSettle();
      expect(Fluxy.isDialogOpen, isTrue);
      expect(Fluxy.routing.isDialog, isTrue);
      Fluxy.back();
      await tester.pumpAndSettle();
      expect(Fluxy.isDialogOpen, isFalse);
      Fluxy.toNamed('/Home');
      await tester.pumpAndSettle();
      expect(Fluxy.currentRoute, '/Home');
      expect(Fluxy.routing.previous, '/');
    });

    testWidgets('routingCallback hears pages and overlays', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(FluxyApp.router(
        getPages: _pages(),
        routingCallback: (r) =>
            seen.add('${r!.current}${r.isDialog == true ? '+dialog' : ''}'),
      ));
      await tester.pumpAndSettle();
      Fluxy.toNamed('/Home');
      await tester.pumpAndSettle();
      Fluxy.dialog(const Text('d'));
      await tester.pumpAndSettle();
      expect(seen, containsAllInOrder(['/Home', '/Home+dialog']));
    });
  });

  group('navigation fixes', () {
    testWidgets('path parameters win over query parameters', (tester) async {
      await tester.pumpWidget(FluxyApp.router(getPages: [
        ..._pages(),
        FluxyPage(name: '/item/:id', page: () => const Text('item')),
      ]));
      await tester.pumpAndSettle();
      Fluxy.toNamed('/item/42?id=7&tab=2');
      await tester.pumpAndSettle();
      expect(find.text('item'), findsOneWidget);
      expect(Fluxy.parameters['id'], '42');
      expect(Fluxy.parameters['tab'], '2');
    });

    testWidgets('showOverlay removes its overlay when the task throws an Error',
        (tester) async {
      await tester.pumpWidget(FluxyApp.router(getPages: _pages()));
      await tester.pumpAndSettle();
      Object? caught;
      Fluxy.showOverlay<void>(
        asyncFunction: () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw StateError('boom');
        },
        loadingWidget: const Text('loading'),
      ).catchError((Object e) => caught = e);
      await tester.pump();
      expect(find.text('loading'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(caught, isA<StateError>());
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('page transitions still run (curve via CurveTween)',
        (tester) async {
      await tester.pumpWidget(FluxyApp.router(getPages: [
        ..._pages(),
        FluxyPage(
          name: '/zoom',
          page: () => const Text('zoom'),
          transition: Transition.zoom,
          curve: Curves.easeOut,
        ),
      ]));
      await tester.pumpAndSettle();
      Fluxy.toNamed('/zoom');
      await tester.pump(); // push (async)
      await tester.pump(); // first transition frame
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('zoom'), findsOneWidget, reason: 'mid-transition');
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      Fluxy.back();
      await tester.pumpAndSettle();
      expect(find.text('zoom'), findsNothing);
    });
  });
}
