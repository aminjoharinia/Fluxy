// The BOOFI app's main.dart routing set-up as of v1.0.0: its own delegate,
// a parser subclass sending '/' to a start route, an unknown page that
// redirects after a frame, and a hand-wired observer for Fluxy.routing.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

bool signedIn = false;
String startRoute() => signedIn ? '/Home' : '/Landing';

List<FluxyPage> appPages() => [
      FluxyPage(name: '/', page: () => const Scaffold(body: Text('root'))),
      FluxyPage(name: '/Home', page: () => const Scaffold(body: Text('home'))),
      FluxyPage(
          name: '/Landing',
          page: () => const Scaffold(body: Text('landing'))),
      FluxyPage(
          name: '/Manage', page: () => const Scaffold(body: Text('manage'))),
    ];

class UnknownRoute extends StatelessWidget {
  const UnknownRoute({super.key});
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Fluxy.offAllNamed(startRoute()));
    return const Scaffold();
  }
}

class AppRouteParser extends FluxyInformationParser {
  AppRouteParser() : super(initialRoute: '/');

  @override
  SynchronousFuture<RouteDecoder> parseRouteInformation(
      RouteInformation routeInformation) {
    final location = routeInformation.uri.toString();
    if (location.isNotEmpty && location != '/') {
      return super.parseRouteInformation(routeInformation);
    }
    return super.parseRouteInformation(RouteInformation(
        uri: Uri.parse(startRoute()), state: routeInformation.state));
  }
}

class RootRoutingObserver extends NavigatorObserver {
  late final FluxyObserver _observer = FluxyObserver(null, Fluxy.routing);
  @override
  void didPush(Route route, Route? previousRoute) =>
      _observer.didPush(route, previousRoute);
  @override
  void didPop(Route route, Route? previousRoute) =>
      _observer.didPop(route, previousRoute);
  @override
  void didRemove(Route route, Route? previousRoute) =>
      _observer.didRemove(route, previousRoute);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) =>
      _observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);
}

Widget boofiApp() {
  final pages = appPages();
  final unknown =
      FluxyPage(name: '/NotFound', page: () => const UnknownRoute());
  return FluxyApp.router(
    getPages: pages,
    unknownRoute: unknown,
    routerDelegate: FluxyDelegate(
      showHashOnUrl: true,
      pages: pages,
      notFoundRoute: unknown,
      navigatorObservers: [RootRoutingObserver()],
    ),
    routeInformationParser: AppRouteParser(),
  );
}

void main() {
  tearDown(() {
    signedIn = false;
    Fluxy.reset();
  });

  testWidgets('signed out: opens on /Landing', (t) async {
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    expect(find.text('landing'), findsOneWidget);
  });

  testWidgets('signed in: opens on /Home', (t) async {
    signedIn = true;
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an unknown address goes to the start route', (t) async {
    signedIn = true;
    await t.pumpWidget(boofiApp());
    await t.pumpAndSettle();
    Fluxy.toNamed('/typo');
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(stackNames(), ['/Home']);
  });

  testWidgets('dialogs and pages work with the app delegate', (t) async {
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
}
