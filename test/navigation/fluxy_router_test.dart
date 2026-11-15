import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

List<GetPage> _pages() => [
      GetPage(name: '/', page: () => const Text('root')),
      GetPage(name: '/Home', page: () => const Text('home')),
      GetPage(name: '/Landing', page: () => const Text('landing')),
    ];

final _unknown = GetPage(name: '/NotFound', page: () => const Text('unknown'));

void main() {
  tearDown(Get.reset);

  group('route matching', () {
    test('only a route for the whole path matches', () {
      final d = GetDelegate(pages: _pages(), notFoundRoute: _unknown);
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
      final d = GetDelegate(pages: [
        GetPage(name: '/', page: () => const SizedBox()),
        GetPage(name: '/item/:id', page: () => const SizedBox()),
      ]);
      final m = d.matchRoute('/item/42');
      expect(m.route?.name, '/item/42');
      expect(m.route?.parameters?['id'], '42');
    });

    testWidgets('an unknown address opens the unknown route', (tester) async {
      await tester.pumpWidget(GetMaterialApp.router(
        getPages: _pages(),
        unknownRoute: _unknown,
      ));
      await tester.pumpAndSettle();
      Get.toNamed('/nope');
      await tester.pumpAndSettle();
      expect(find.text('unknown'), findsOneWidget);
    });
  });

  group('initialRoute', () {
    testWidgets('an explicit initialRoute wins over a registered "/"',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp.router(
        getPages: _pages(),
        initialRoute: '/Landing',
      ));
      await tester.pumpAndSettle();
      expect(find.text('landing'), findsOneWidget);
    });

    testWidgets('without one, "/" opens its own page', (tester) async {
      await tester.pumpWidget(GetMaterialApp.router(getPages: _pages()));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    test('parser: redirect only when asked or when "/" is no page', () {
      final redirect = GetInformationParser(
          initialRoute: '/Landing', redirectRootToInitialRoute: true);
      final plain = GetInformationParser(initialRoute: '/Landing');
      expect(redirect.redirectRootToInitialRoute, isTrue);
      expect(plain.redirectRootToInitialRoute, isFalse);
    });
  });

  group('routing observer', () {
    testWidgets('an app-provided delegate still keeps Get.routing current',
        (tester) async {
      final delegate = GetDelegate(pages: _pages());
      await tester.pumpWidget(GetMaterialApp.router(
        getPages: _pages(),
        routerDelegate: delegate,
      ));
      await tester.pumpAndSettle();
      expect(delegate.routingObserver, isNotNull);

      Get.dialog(const Text('dialog'));
      await tester.pumpAndSettle();
      expect(Get.isDialogOpen, isTrue);
      Get.back();
      await tester.pumpAndSettle();
      expect(Get.isDialogOpen, isFalse);
    });

    testWidgets('no second observer when the app listed a GetObserver',
        (tester) async {
      final delegate = GetDelegate(
        pages: _pages(),
        navigatorObservers: [GetObserver()],
      );
      await tester.pumpWidget(GetMaterialApp.router(
        getPages: _pages(),
        routerDelegate: delegate,
      ));
      await tester.pumpAndSettle();
      expect(delegate.routingObserver, isNull);
    });
  });
}
