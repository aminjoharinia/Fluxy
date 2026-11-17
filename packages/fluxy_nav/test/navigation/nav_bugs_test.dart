// The bugs B1-B7 from NAV-PLAN.md, confirmed on v1.0.0. Each test is skipped
// until the phase that fixes it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

Widget text(String s) => Scaffold(body: Text(s));

class Detail extends StatelessWidget {
  const Detail({super.key});
  @override
  Widget build(BuildContext context) => text('detail');
}

class SlowMiddleware extends FluxyMiddleware {
  SlowMiddleware(this.gate);
  final Completer<void> gate;
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    await gate.future;
    return route;
  }
}

class OrderMiddleware extends FluxyMiddleware {
  OrderMiddleware(this.log, this.tag, {super.priority});
  final List<String> log;
  final String tag;
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    log.add(tag);
    return route;
  }
}

void main() {
  tearDown(Fluxy.reset);

  testWidgets('B1: a static route wins over an earlier /:id', (t) async {
    await t.pumpWidget(FluxyApp.router(getPages: [
      FluxyPage(name: '/', page: () => text('root')),
      FluxyPage(name: '/:id', page: () => text('item')),
      FluxyPage(name: '/settings', page: () => text('settings')),
    ]));
    await t.pumpAndSettle();
    Fluxy.toNamed('/settings');
    await t.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(Fluxy.parameters['id'], isNull);
  }, skip: true);

  testWidgets('B2: navigations apply in call order', (t) async {
    final gate = Completer<void>();
    await t.pumpWidget(FluxyApp.router(getPages: [
      FluxyPage(name: '/', page: () => text('root')),
      FluxyPage(
          name: '/a',
          page: () => text('a'),
          middlewares: [SlowMiddleware(gate)]),
      FluxyPage(name: '/b', page: () => text('b')),
    ]));
    await t.pumpAndSettle();
    Fluxy.toNamed('/a');
    Fluxy.toNamed('/b');
    await t.pump();
    gate.complete();
    await t.pumpAndSettle();
    expect(stackNames(), ['/', '/a', '/b']);
    expect(find.text('b'), findsOneWidget);
  }, skip: true);

  testWidgets('B3: currentRoute is the address inside nested pages',
      (t) async {
    await t.pumpWidget(FluxyApp.router(
      initialRoute: '/shell/x',
      getPages: [
        FluxyPage(
          name: '/shell',
          participatesInRootNavigator: true,
          page: () => Scaffold(
            body: FluxyRouterOutlet(
                initialRoute: '/shell/x', anchorRoute: '/shell'),
          ),
          children: [
            FluxyPage(name: '/x', page: () => const Text('x')),
          ],
        ),
      ],
    ));
    await t.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
    expect(Fluxy.currentRoute, '/shell/x');
  }, skip: true);

  testWidgets('B4: Fluxy.to does not change the route table', (t) async {
    await t.pumpWidget(FluxyApp.router(getPages: [
      FluxyPage(name: '/', page: () => text('root')),
    ]));
    await t.pumpAndSettle();
    final delegate = Fluxy.rootController.rootDelegate;
    final before = delegate.registeredRoutes.length;
    Fluxy.to(() => const Detail());
    await t.pumpAndSettle();
    expect(delegate.registeredRoutes.length, before);
  }, skip: true);

  testWidgets('B5: a pop inside an outlet updates the stack and the URL',
      (t) async {
    await t.pumpWidget(FluxyApp.router(
      initialRoute: '/shell',
      getPages: [
        FluxyPage(
          name: '/shell',
          participatesInRootNavigator: true,
          page: () => Scaffold(
            body: FluxyRouterOutlet(
                initialRoute: '/shell/a', anchorRoute: '/shell'),
          ),
          children: [
            FluxyPage(name: '/a', page: () => const Text('a')),
            FluxyPage(
              name: '/b',
              page: () => const Text('b'),
              children: [
                FluxyPage(name: '/c', page: () => const Text('c')),
              ],
            ),
          ],
        ),
      ],
    ));
    await t.pumpAndSettle();
    Fluxy.toNamed('/shell/b/c');
    await t.pumpAndSettle();
    expect(find.text('c'), findsOneWidget);
    Navigator.of(t.element(find.text('c'))).pop();
    await t.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    expect(Fluxy.currentRoute, '/shell/b');
  }, skip: true);

  testWidgets('B6: an outlet two levels down shows its own pages', (t) async {
    await t.pumpWidget(FluxyApp.router(
      initialRoute: '/a/b/c',
      getPages: [
        FluxyPage(
          name: '/a',
          participatesInRootNavigator: true,
          page: () =>
              Scaffold(body: FluxyRouterOutlet(initialRoute: '/a/b')),
          children: [
            FluxyPage(
              name: '/b',
              page: () => FluxyRouterOutlet(initialRoute: '/a/b/c'),
              children: [
                FluxyPage(name: '/c', page: () => const Text('c')),
              ],
            ),
          ],
        ),
      ],
    ));
    await t.pumpAndSettle();
    expect(find.text('c'), findsOneWidget);
  }, skip: true);

  testWidgets('B7: middleware priority is honoured on the router', (t) async {
    final log = <String>[];
    await t.pumpWidget(FluxyApp.router(getPages: [
      FluxyPage(name: '/', page: () => text('root')),
      FluxyPage(name: '/a', page: () => text('a'), middlewares: [
        OrderMiddleware(log, 'late', priority: 5),
        OrderMiddleware(log, 'early', priority: -1),
      ]),
    ]));
    await t.pumpAndSettle();
    Fluxy.toNamed('/a');
    await t.pumpAndSettle();
    expect(log, ['early', 'late']);
  }, skip: true);
}
