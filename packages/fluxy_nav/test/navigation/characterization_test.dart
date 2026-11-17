// Behaviour the BOOFI app relies on, pinned before the router is rebuilt
// (NAV-PLAN.md phase 0). These must stay green through every phase.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

class Detail extends StatelessWidget {
  const Detail({super.key, this.label = 'detail'});
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

class Other extends StatelessWidget {
  const Other({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('other'));
}

List<FluxyPage> flatPages() => [
  FluxyPage(
    name: '/',
    page: () => const Scaffold(body: Text('root')),
  ),
  FluxyPage(
    name: '/Home',
    page: () => const Scaffold(body: Text('home')),
  ),
  FluxyPage(
    name: '/Landing',
    page: () => const Scaffold(body: Text('landing')),
    transition: Transition.cupertino,
  ),
  FluxyPage(
    name: '/Manage',
    page: () => const Scaffold(body: Text('manage')),
    transition: Transition.zoom,
  ),
];

final notFound = FluxyPage(
  name: '/NotFound',
  page: () => const Scaffold(body: Text('nf')),
);

Future<void> pumpApp(WidgetTester t, {String? initialRoute}) async {
  await t.pumpWidget(
    FluxyApp.router(
      getPages: flatPages(),
      unknownRoute: notFound,
      initialRoute: initialRoute,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  tearDown(Fluxy.reset);

  group('Fluxy.back order', () {
    testWidgets('snackbar, then dialog, then page; the last page stays', (
      t,
    ) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      Fluxy.dialog(const Text('dialog'));
      await t.pumpAndSettle();
      Fluxy.rawSnackbar(
        message: 'snack',
        duration: const Duration(seconds: 30),
        animationDuration: const Duration(milliseconds: 10),
      );
      await t.pumpAndSettle();
      expect(find.text('snack'), findsOneWidget);
      expect(find.text('dialog'), findsOneWidget);

      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('snack'), findsNothing);
      expect(find.text('dialog'), findsOneWidget);

      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(Fluxy.isDialogOpen, isFalse);

      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(stackNames(), ['/']);

      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget, reason: 'last page is kept');
      expect(stackNames(), ['/']);
    });

    testWidgets('a bottom sheet closes before the page', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      Fluxy.bottomSheet(const Material(child: Text('sheet')));
      await t.pumpAndSettle();
      expect(Fluxy.isBottomSheetOpen, isTrue);
      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(Fluxy.isBottomSheetOpen, isFalse);
    });

    testWidgets('a sheet on the first page closes; the page stays', (t) async {
      await pumpApp(t);
      Fluxy.bottomSheet(const Material(child: Text('sheet')));
      await t.pumpAndSettle();
      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('root'), findsOneWidget);
    });
  });

  group('closeAllDialogs', () {
    testWidgets('closes every open dialog and nothing else', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      Fluxy.dialog(const Text('one'));
      await t.pumpAndSettle();
      Fluxy.dialog(const Text('two'));
      await t.pumpAndSettle();
      Fluxy.closeAllDialogs();
      await t.pumpAndSettle();
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(Fluxy.isDialogOpen, isFalse);
    });

    testWidgets('with no dialog open it does not pop the page', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      Fluxy.closeAllDialogs();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(stackNames(), ['/', '/Home']);
    });

    testWidgets('a dialog over a sheet: only the dialog closes', (t) async {
      await pumpApp(t);
      Fluxy.bottomSheet(const Material(child: Text('sheet')));
      await t.pumpAndSettle();
      Fluxy.dialog(const Text('dialog'));
      await t.pumpAndSettle();
      Fluxy.closeAllDialogs();
      await t.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(find.text('sheet'), findsOneWidget);
      expect(Fluxy.isBottomSheetOpen, isTrue);
    });
  });

  group('overlay results', () {
    testWidgets('dialog result through Fluxy.back(result:)', (t) async {
      await pumpApp(t);
      final f = Fluxy.dialog<String>(const Text('d'));
      await t.pumpAndSettle();
      expect(Fluxy.isDialogOpen, isTrue);
      Fluxy.back(result: 'ok');
      await t.pumpAndSettle();
      expect(await f, 'ok');
    });

    testWidgets('defaultDialog confirm runs onConfirm', (t) async {
      await pumpApp(t);
      var confirmed = false;
      Fluxy.defaultDialog(
        middleText: 'sure?',
        onConfirm: () {
          confirmed = true;
          Fluxy.back();
        },
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Ok'));
      await t.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.text('sure?'), findsNothing);
    });

    testWidgets('generalDialog result through closeDialog', (t) async {
      await pumpApp(t);
      final f = Fluxy.generalDialog<int>(
        pageBuilder: (_, _, _) => const Text('g'),
      );
      await t.pumpAndSettle();
      expect(find.text('g'), findsOneWidget);
      Fluxy.closeDialog(result: 7);
      await t.pumpAndSettle();
      expect(await f, 7);
    });

    testWidgets('bottomSheet result through Fluxy.back(result:)', (t) async {
      await pumpApp(t);
      final f = Fluxy.bottomSheet<bool>(const Material(child: Text('s')));
      await t.pumpAndSettle();
      Fluxy.back(result: true);
      await t.pumpAndSettle();
      expect(await f, isTrue);
    });
  });

  group('pages', () {
    offNamedDuplicates();

    testWidgets('to() with a transition; its future gets the back result', (
      t,
    ) async {
      await pumpApp(t);
      final f = Fluxy.to<String>(
        () => const Detail(),
        transition: Transition.cupertino,
      );
      await t.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(Fluxy.currentRoute, '/Detail');
      Fluxy.back(result: 'done');
      await t.pumpAndSettle();
      expect(await f, 'done');
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('Navigator.pop on a page: the stack follows and the future '
        'gets the value', (t) async {
      await pumpApp(t);
      final f = Fluxy.to<int>(() => const Detail());
      await t.pumpAndSettle();
      Navigator.of(t.element(find.text('detail'))).pop(3);
      await t.pumpAndSettle();
      expect(await f, 3);
      expect(stackNames(), ['/']);
      expect(Fluxy.currentRoute, '/');
    });

    testWidgets('to() the same page twice keeps one copy', (t) async {
      await pumpApp(t);
      Fluxy.to(() => const Detail(label: 'one'));
      await t.pumpAndSettle();
      Fluxy.to(() => const Detail(label: 'two'));
      await t.pumpAndSettle();
      expect(stackNames().where((n) => n == '/Detail').length, 1);
    });

    testWidgets('offAll with zoom + duration leaves only the new page and '
        'completes the removed futures', (t) async {
      await pumpApp(t);
      var done = 0;
      Fluxy.toNamed('/Home')!.then((_) => done++);
      await t.pumpAndSettle();
      Fluxy.to(() => const Detail())!.then((_) => done++);
      await t.pumpAndSettle();
      Fluxy.offAll(
        () => const Other(),
        transition: Transition.zoom,
        duration: const Duration(milliseconds: 500),
      );
      await t.pumpAndSettle();
      expect(find.text('other'), findsOneWidget);
      expect(stackNames(), ['/Other']);
      expect(done, 2);
      Fluxy.back();
      await t.pumpAndSettle();
      expect(find.text('other'), findsOneWidget);
    });

    testWidgets('offAllNamed replaces the whole stack', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      Fluxy.toNamed('/Manage');
      await t.pumpAndSettle();
      Fluxy.offAllNamed('/Landing');
      await t.pumpAndSettle();
      expect(stackNames(), ['/Landing']);
      expect(find.text('landing'), findsOneWidget);
      expect(Fluxy.currentRoute, '/Landing');
    });

    testWidgets('an unknown address opens unknownRoute', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/typo');
      await t.pumpAndSettle();
      expect(find.text('nf'), findsOneWidget);
    });

    testWidgets('currentRoute / previousRoute follow toNamed and back', (
      t,
    ) async {
      await pumpApp(t);
      expect(Fluxy.currentRoute, '/');
      Fluxy.toNamed('/Home');
      await t.pumpAndSettle();
      expect(Fluxy.currentRoute, '/Home');
      expect(Fluxy.previousRoute, '/');
      Fluxy.back();
      await t.pumpAndSettle();
      expect(Fluxy.currentRoute, '/');
    });

    testWidgets('arguments reach the page', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home', arguments: 42);
      await t.pumpAndSettle();
      expect(Fluxy.arguments, 42);
    });

    testWidgets('initialRoute opens that page', (t) async {
      await pumpApp(t, initialRoute: '/Landing');
      expect(find.text('landing'), findsOneWidget);
    });
  });

  group('globals', () {
    testWidgets('Fluxy.key, Fluxy.context, overlayContext', (t) async {
      await pumpApp(t);
      expect(Fluxy.key.currentState, isNotNull);
      expect(Fluxy.context, isNotNull);
      expect(Fluxy.overlayContext, isNotNull);
      expect(Fluxy.key.currentState!.overlay, isNotNull);
    });

    testWidgets('the delegate reports the location for the URL', (t) async {
      await pumpApp(t);
      Fluxy.toNamed('/Home?tab=2');
      await t.pumpAndSettle();
      final router = Router.of(Fluxy.context!);
      final info = router.routeInformationParser!.restoreRouteInformation(
        router.routerDelegate.currentConfiguration,
      );
      expect(info?.uri.toString(), '/Home?tab=2');
    });

    test('hash URLs are the default (no path URL strategy is set)', () {
      // showHashOnUrl defaults to true; on the VM nothing is changed.
      expect(() => FluxyDelegate(pages: flatPages()), returnsNormally);
      expect(kIsWeb, isFalse);
    });
  });
}

void offNamedDuplicates() {
  testWidgets('offNamed to a page already below keeps one copy', (t) async {
    await pumpApp(t);
    Fluxy.toNamed('/Home');
    await t.pumpAndSettle();
    Fluxy.toNamed('/Manage');
    await t.pumpAndSettle();
    Fluxy.offNamed('/Home');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(stackNames(), ['/', '/Home']);
    expect(find.text('home'), findsOneWidget);
  });
}
