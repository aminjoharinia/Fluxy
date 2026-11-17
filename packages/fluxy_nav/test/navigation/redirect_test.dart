import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

Widget text(String s) => Scaffold(body: Text(s));

Future<void> pump(
  WidgetTester t,
  List<FluxyPage> pages, {
  FluxyRedirect? redirect,
  String? initialRoute,
}) async {
  await t.pumpWidget(
    FluxyApp.router(
      getPages: [
        FluxyPage(name: '/', page: () => text('root')),
        ...pages,
      ],
      redirect: redirect,
      initialRoute: initialRoute,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  tearDown(Fluxy.reset);

  testWidgets('a page redirect sends the navigation elsewhere', (t) async {
    await pump(t, [
      FluxyPage(
        name: '/first',
        page: () => text('first'),
        redirect: (_) => '/second',
      ),
      FluxyPage(name: '/second', page: () => text('second')),
    ]);
    Fluxy.toNamed('/first');
    await t.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(Fluxy.currentRoute, '/second');
    expect(Fluxy.previousRoute, '/');
    Fluxy.back();
    await t.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('NavRequest.stop cancels; the future completes with null', (
    t,
  ) async {
    await pump(t, [
      FluxyPage(
        name: '/first',
        page: () => text('first'),
        redirect: (_) => NavRequest.stop,
      ),
    ]);
    final f = Fluxy.toNamed('/first');
    await t.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(stackNames(), ['/']);
    expect(await f, isNull);
  });

  testWidgets('null lets it through', (t) async {
    await pump(t, [
      FluxyPage(
        name: '/first',
        page: () => text('first'),
        redirect: (_) => null,
      ),
    ]);
    Fluxy.toNamed('/first');
    await t.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('chained redirects; each target runs its own', (t) async {
    await pump(t, [
      FluxyPage(name: '/a', page: () => text('a'), redirect: (_) => '/b'),
      FluxyPage(name: '/b', page: () => text('b'), redirect: (_) => '/c'),
      FluxyPage(name: '/c', page: () => text('c')),
    ]);
    Fluxy.toNamed('/a');
    await t.pumpAndSettle();
    expect(find.text('c'), findsOneWidget);
    expect(stackNames(), ['/', '/c']);
  });

  testWidgets('asynchronous redirects; later navigations wait', (t) async {
    final gate = Completer<String?>();
    await pump(t, [
      FluxyPage(
        name: '/slow',
        page: () => text('slow'),
        redirect: (_) => gate.future,
      ),
      FluxyPage(name: '/login', page: () => text('login')),
      FluxyPage(name: '/next', page: () => text('next')),
    ]);
    Fluxy.toNamed('/slow');
    Fluxy.toNamed('/next');
    await t.pump();
    expect(stackNames(), ['/']);
    gate.complete('/login');
    await t.pumpAndSettle();
    expect(stackNames(), ['/', '/login', '/next']);
  });

  testWidgets('children inherit their parents redirects', (t) async {
    var authed = false;
    await pump(t, [
      FluxyPage(name: '/login', page: () => text('login')),
      FluxyPage(
        name: '/admin',
        page: () => text('admin'),
        redirect: (r) => authed ? null : '/login?then=${r.location}',
        children: [FluxyPage(name: '/users', page: () => text('users'))],
      ),
    ]);
    Fluxy.toNamed('/admin/users');
    await t.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
    expect(Fluxy.parameters['then'], '/admin/users');
    authed = true;
    Fluxy.toNamed('/admin/users');
    await t.pumpAndSettle();
    expect(find.text('users'), findsOneWidget);
  });

  testWidgets('the app redirect runs for the first address', (t) async {
    final seen = <NavRequest>[];
    await pump(
      t,
      [FluxyPage(name: '/start', page: () => text('start'))],
      redirect: (r) {
        seen.add(r);
        return r.path == '/' ? '/start' : null;
      },
    );
    expect(find.text('start'), findsOneWidget);
    expect(seen.first.isInitial, isTrue);
    expect(seen.first.path, '/');
    expect(stackNames(), ['/start']);
  });

  testWidgets('the app redirect sees unknown addresses', (t) async {
    await pump(t, [
      FluxyPage(name: '/home', page: () => text('home')),
    ], redirect: (r) => r.isUnknown ? '/home' : null);
    Fluxy.toNamed('/nope');
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(Fluxy.routing.previous, '/');
  });

  testWidgets('the app redirect is not run for Fluxy.to pages', (t) async {
    var calls = 0;
    await pump(
      t,
      [],
      redirect: (_) {
        calls++;
        return null;
      },
    );
    calls = 0;
    Fluxy.to(() => text('direct'));
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('direct'), findsOneWidget);
  });

  testWidgets('arguments survive a redirect', (t) async {
    await pump(t, [
      FluxyPage(name: '/a', page: () => text('a'), redirect: (_) => '/b'),
      FluxyPage(name: '/b', page: () => text('b')),
    ]);
    Fluxy.toNamed('/a', arguments: 7);
    await t.pumpAndSettle();
    expect(Fluxy.arguments, 7);
  });

  testWidgets('a redirect loop is stopped and reported', (t) async {
    await pump(t, [
      FluxyPage(name: '/a', page: () => text('a'), redirect: (_) => '/b'),
      FluxyPage(name: '/b', page: () => text('b'), redirect: (_) => '/a'),
    ]);
    Fluxy.toNamed('/a');
    await t.pumpAndSettle();
    expect(t.takeException(), isStateError);
    expect(stackNames(), ['/']);
  });

  testWidgets('a throwing redirect cancels and is reported', (t) async {
    await pump(t, [
      FluxyPage(
        name: '/a',
        page: () => text('a'),
        redirect: (_) async => throw StateError('no'),
      ),
    ]);
    final f = Fluxy.toNamed('/a');
    await t.pumpAndSettle();
    expect(t.takeException(), isStateError);
    expect(await f, isNull);
    expect(stackNames(), ['/']);
  });

  testWidgets('a redirect to its own address goes there', (t) async {
    await pump(t, [
      FluxyPage(name: '/a', page: () => text('a'), redirect: (r) => r.location),
    ]);
    Fluxy.toNamed('/a');
    await t.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('onEnter / onLeave follow the stack', (t) async {
    final log = <String>[];
    await pump(t, [
      FluxyPage(
        name: '/a',
        page: () => text('a'),
        onEnter: (m) => log.add('enter ${m.location}'),
        onLeave: (m) => log.add('leave ${m.location}'),
      ),
    ]);
    Fluxy.toNamed('/a?x=1');
    await t.pumpAndSettle();
    Fluxy.back();
    await t.pumpAndSettle();
    expect(log, ['enter /a?x=1', 'leave /a?x=1']);
  });
}
