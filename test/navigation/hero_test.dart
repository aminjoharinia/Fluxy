import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const _shuttleKey = ValueKey('shuttle');

Widget _home() => Builder(
  builder: (context) => Scaffold(
    body: GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, _, _) => const Scaffold(
            body: Hero(
              tag: 'room',
              child: SizedBox.expand(
                child: ColoredBox(key: _shuttleKey, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
      child: const Center(
        child: Hero(
          tag: 'room',
          child: SizedBox(
            width: 50,
            height: 50,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    ),
  ),
);

int _shuttles() =>
    find.byKey(_shuttleKey, skipOffstage: false).evaluate().length;

Future<void> _pumpApp(WidgetTester tester, GetDelegate delegate) async {
  await tester.pumpWidget(
    GetMaterialApp.router(
      getPages: [GetPage(name: '/', page: _home)],
      routerDelegate: delegate,
      routeInformationParser: GetInformationParser(initialRoute: '/'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('root navigator adds no HeroController of its own', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      GetDelegate(
        pages: [GetPage(name: '/', page: _home)],
      ),
    );
    final nav = tester.widget<GetNavigator>(find.byType(GetNavigator).first);
    expect(nav.observers.whereType<HeroController>(), isEmpty);
  });

  testWidgets('a hero flies once on the root navigator', (tester) async {
    await _pumpApp(
      tester,
      GetDelegate(
        pages: [GetPage(name: '/', page: _home)],
      ),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Mid-flight, each running flight draws one shuttle in the overlay.
    expect(_shuttles(), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('a router rebuild mid-flight keeps the single flight', (
    tester,
  ) async {
    final delegate = GetDelegate(
      pages: [GetPage(name: '/', page: _home)],
    );
    await _pumpApp(tester, delegate);
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    delegate.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_shuttles(), 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GetHeroScope makes one controller when there is no app scope', (
    tester,
  ) async {
    late HeroController? first;
    Widget app() => Directionality(
      textDirection: TextDirection.ltr,
      child: GetHeroScope(
        child: Builder(
          builder: (context) {
            first = HeroControllerScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(app());
    final created = first;
    expect(created, isNotNull);
    await tester.pumpWidget(app());
    expect(first, same(created), reason: 'kept across rebuilds');
  });

  testWidgets('GetHeroScope uses the app scope unless nested', (tester) async {
    final outer = HeroController();
    HeroController? root;
    HeroController? nested;
    await tester.pumpWidget(
      HeroControllerScope(
        controller: outer,
        child: Column(
          children: [
            GetHeroScope(
              child: Builder(
                builder: (c) {
                  root = HeroControllerScope.maybeOf(c);
                  return const SizedBox();
                },
              ),
            ),
            GetHeroScope(
              nested: true,
              child: Builder(
                builder: (c) {
                  nested = HeroControllerScope.maybeOf(c);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(root, same(outer));
    expect(nested, isNot(same(outer)));
    outer.dispose();
  });
}
