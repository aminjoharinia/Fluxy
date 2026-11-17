import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

import 'utils/stack.dart';

int shellBuilds = 0;

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    shellBuilds++;
    return Scaffold(
      appBar: AppBar(title: const Text('shell')),
      body: const FluxyRouterOutlet(parent: '/', levels: 1),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('home-bar'),
      const Expanded(
        child: FluxyRouterOutlet(
          parent: '/home',
          initialRoute: '/home/dashboard',
        ),
      ),
    ],
  );
}

class Detail extends StatelessWidget {
  const Detail({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('detail'));
}

List<FluxyPage> pages() => [
  FluxyPage(
    name: '/',
    participatesInRootNavigator: true,
    page: () => const Shell(),
    children: [
      FluxyPage(
        name: '/home',
        page: () => const Home(),
        children: [
          FluxyPage(name: '/dashboard', page: () => const Text('dashboard')),
          FluxyPage(
            name: '/products',
            participatesInRootNavigator: false,
            page: () => const Text('products'),
            children: [
              FluxyPage(
                name: '/:id',
                page: () =>
                    Builder(builder: (c) => Text('product ${c.params['id']}')),
              ),
            ],
          ),
        ],
      ),
      FluxyPage(name: '/settings', page: () => const Text('settings')),
    ],
  ),
];

String url() {
  final router = Router.of(Fluxy.context!);
  return router.routeInformationParser!
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)!
      .uri
      .toString();
}

void main() {
  tearDown(() {
    shellBuilds = 0;
    Fluxy.reset();
  });

  Future<void> pump(WidgetTester t, String initial) async {
    await t.pumpWidget(
      FluxyApp.router(getPages: pages(), initialRoute: initial),
    );
    await t.pumpAndSettle();
  }

  testWidgets('nested outlets show their level of the address', (t) async {
    await pump(t, '/home/dashboard');
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('home-bar'), findsOneWidget);
    expect(find.text('dashboard'), findsOneWidget);
    expect(Fluxy.currentRoute, '/home/dashboard');
  });

  testWidgets('the address of the parent shows initialRoute', (t) async {
    await pump(t, '/home');
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('deeper pages stack inside the outlet; a pop there moves the '
      'address up and the URL follows', (t) async {
    await pump(t, '/home/dashboard');
    Fluxy.toNamed('/home/products/7');
    await t.pumpAndSettle();
    expect(find.text('product 7'), findsOneWidget);
    expect(url(), '/home/products/7');
    Navigator.of(t.element(find.text('product 7'))).pop();
    await t.pumpAndSettle();
    expect(find.text('products'), findsOneWidget);
    expect(find.text('product 7'), findsNothing);
    expect(Fluxy.currentRoute, '/home/products');
    expect(url(), '/home/products');
    expect(stackNames(), ['/home/dashboard', '/home/products']);
  });

  testWidgets('a pop in the outlet returns to the entry below when it is '
      'the parent page', (t) async {
    await pump(t, '/home/products');
    var popped = false;
    Fluxy.toNamed('/home/products/3')!.then((_) => popped = true);
    await t.pumpAndSettle();
    Navigator.of(t.element(find.text('product 3'))).pop();
    await t.pumpAndSettle();
    expect(stackNames(), ['/home/products']);
    expect(popped, isTrue);
  });

  testWidgets('the shell is built once and kept across entries', (t) async {
    await pump(t, '/home/dashboard');
    final builds = shellBuilds;
    Fluxy.toNamed('/settings');
    await t.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    Fluxy.back();
    await t.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
    expect(find.byType(Shell), findsOneWidget);
    expect(shellBuilds, builds, reason: 'same page key, same route');
  });

  testWidgets('a Fluxy.to page goes over the shell; back shows it again', (
    t,
  ) async {
    await pump(t, '/home/dashboard');
    Fluxy.to(() => const Detail());
    await t.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(Fluxy.currentRoute, '/Detail');
    Fluxy.back();
    await t.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('arguments and parameters come from the address', (t) async {
    await pump(t, '/home/dashboard');
    Fluxy.toNamed('/home/products/9?tab=2', arguments: 'x');
    await t.pumpAndSettle();
    expect(Fluxy.parameters, {'id': '9', 'tab': '2'});
    expect(Fluxy.arguments, 'x');
  });
}
