// The BOOFI app's main.dart routing set-up from v1.2.0: one FluxyApp.router
// with `redirect:` instead of its own delegate, a parser subclass, an
// UnknownRoute page redirecting after a frame and a hand-wired observer.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

bool signedIn = false;
String startRoute() => signedIn ? '/Home' : '/Landing';

List<FluxyPage> appPages() => [
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
  ),
  FluxyPage(
    name: '/Manage',
    page: () => const Scaffold(body: Text('manage')),
  ),
];

Widget boofiApp({String? opened}) => FluxyApp.router(
  getPages: appPages(),
  redirect: (r) => r.isUnknown || r.path == '/' ? startRoute() : null,
  routeInformationProvider: opened == null
      ? null
      : PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(uri: Uri.parse(opened)),
        ),
);

void main() {
  tearDown(() {
    signedIn = false;
    Fluxy.reset();
  });

  testWidgets('signed out: opens on /Landing', (t) async {
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    expect(find.text('landing'), findsOneWidget);
    expect(stackNames(), ['/Landing']);
  });

  testWidgets('signed in: opens on /Home', (t) async {
    signedIn = true;
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('opened at an unknown address: the start route', (t) async {
    signedIn = true;
    await t.pumpWidget(boofiApp(opened: '/old-bookmark'));
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(Fluxy.currentRoute, '/Home');
  });

  testWidgets('opened at a page: that page', (t) async {
    await t.pumpWidget(boofiApp(opened: '/Manage'));
    await t.pumpAndSettle();
    expect(find.text('manage'), findsOneWidget);
  });

  testWidgets('an unknown address later goes to the start route', (t) async {
    signedIn = true;
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    Fluxy.toNamed('/typo');
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(stackNames(), ['/Home']);
  });

  testWidgets('dialogs and pages, no observer', (t) async {
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    Fluxy.toNamed('/Manage');
    await t.pumpAndSettle();
    Fluxy.dialog(const Text('dialog'));
    await t.pumpAndSettle();
    expect(Fluxy.isDialogOpen, isTrue);
    Fluxy.closeAllDialogs();
    await t.pumpAndSettle();
    expect(Fluxy.isDialogOpen, isFalse);
    expect(find.text('manage'), findsOneWidget);
    Fluxy.back();
    await t.pumpAndSettle();
    expect(find.text('landing'), findsOneWidget);
  });

  testWidgets('sign-in then offAll to the home page', (t) async {
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    signedIn = true;
    Fluxy.offAllNamed(startRoute());
    await t.pumpAndSettle();
    expect(stackNames(), ['/Home']);
  });
}
