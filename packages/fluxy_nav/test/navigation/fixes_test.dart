// Regressions found in the v1.2.0 review.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

class Detail extends StatelessWidget {
  const Detail(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Text('detail $id'));
}

class Box<T> extends StatelessWidget {
  const Box({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget app() => FluxyApp(
  getPages: [
    FluxyPage(name: '/', page: () => const Scaffold(body: Text('root'))),
    FluxyPage(
      name: '/item/:id',
      page: () => const Scaffold(body: Text('item')),
    ),
  ],
);

List<String> locations() => [
  for (final e in Fluxy.rootController.rootDelegate.stack.entries) e.location,
];

void main() {
  tearDown(() => Fluxy.reset());

  group('parameters with a query in the address', () {
    testWidgets('toNamed merges them into the query', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      Fluxy.toNamed('/item/1?a=1', parameters: {'q': 'x'});
      await t.pumpAndSettle();
      expect(locations(), ['/', '/item/1?a=1&q=x']);
      expect(Fluxy.parameters, {'a': '1', 'q': 'x', 'id': '1'});
    });

    testWidgets('a parameter replaces a query value of the same name', (
      t,
    ) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      Fluxy.offAllNamed('/item/2?q=old', parameters: {'q': 'new'});
      await t.pumpAndSettle();
      expect(locations(), ['/item/2?q=new']);
    });

    testWidgets('offNamed and offAndToNamed too', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      Fluxy.toNamed('/item/1');
      await t.pumpAndSettle();
      Fluxy.offNamed('/item/2?a=1', parameters: {'b': '2'});
      await t.pumpAndSettle();
      expect(locations(), ['/', '/item/2?a=1&b=2']);
      Fluxy.offAndToNamed('/item/3?a=1', parameters: {'c': '3'});
      await t.pumpAndSettle();
      expect(locations(), ['/', '/item/3?a=1&c=3']);
    });
  });

  testWidgets('Fluxy.to of the same widget type shows the new one', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final first = Fluxy.to(() => const Detail(1));
    await t.pumpAndSettle();
    Fluxy.to(() => const Detail(2));
    await t.pumpAndSettle();
    expect(find.text('detail 2'), findsOneWidget);
    expect(find.text('detail 1'), findsNothing);
    expect(locations(), ['/', '/Detail']);
    expect(await first, isNull);
    Fluxy.back();
    await t.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('back(times:) counts an open dialog as one step', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    Fluxy.toNamed('/item/1');
    await t.pumpAndSettle();
    Fluxy.toNamed('/item/2');
    await t.pumpAndSettle();
    Fluxy.dialog(const Text('dlg'));
    await t.pumpAndSettle();
    Fluxy.back(times: 2);
    await t.pumpAndSettle();
    expect(Fluxy.isDialogOpen, isFalse);
    expect(find.text('dlg'), findsNothing);
    expect(locations(), ['/', '/item/1']);
  });

  testWidgets('back(times:) with only dialogs open leaves the pages', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    Fluxy.toNamed('/item/1');
    await t.pumpAndSettle();
    Fluxy.dialog(const Text('one'));
    await t.pumpAndSettle();
    Fluxy.dialog(const Text('two'));
    await t.pumpAndSettle();
    Fluxy.back(times: 2);
    await t.pumpAndSettle();
    expect(Fluxy.isDialogOpen, isFalse);
    expect(locations(), ['/', '/item/1']);
  });

  group('improvements', () {
    testWidgets('an unknown address keeps its address', (t) async {
      await t.pumpWidget(
        FluxyApp(
          unknownRoute: FluxyPage(
            name: '/404',
            page: () => const Scaffold(body: Text('nf')),
          ),
          getPages: [
            FluxyPage(name: '/', page: () => const Scaffold(body: Text('root'))),
          ],
        ),
      );
      await t.pumpAndSettle();
      Fluxy.toNamed('/typo?from=mail');
      await t.pumpAndSettle();
      expect(find.text('nf'), findsOneWidget);
      expect(locations(), ['/', '/typo?from=mail']);
      expect(Fluxy.currentRoute, '/typo');
      expect(Fluxy.parameters['from'], 'mail');
      expect(
        Fluxy.rootController.rootDelegate.currentConfiguration.toString(),
        '/typo?from=mail',
      );
    });

    testWidgets('an empty redirect address is reported and cancels', (
      t,
    ) async {
      await t.pumpWidget(
        FluxyApp(
          getPages: [
            FluxyPage(name: '/', page: () => const Scaffold(body: Text('root'))),
            FluxyPage(
              name: '/a',
              page: () => const Scaffold(body: Text('a')),
              redirect: (_) => '',
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      final f = Fluxy.toNamed('/a');
      await t.pumpAndSettle();
      expect(t.takeException(), isArgumentError);
      expect(await f, isNull);
      expect(locations(), ['/']);
    });

    test('directRouteName', () {
      expect(FluxyDelegate.directRouteName(() => const Detail(1)), '/Detail');
      expect(
        FluxyDelegate.directRouteName(() => const SizedBox()),
        '/SizedBox',
      );
      expect(
        FluxyDelegate.directRouteName(() => const Box<int>()),
        '/Box',
      );
    });

    testWidgets('the home page is /', (t) async {
      await t.pumpWidget(const FluxyApp(home: Scaffold(body: Text('home'))));
      await t.pumpAndSettle();
      expect(Fluxy.currentRoute, '/');
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('topRoute follows pages and dialogs', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final delegate = Fluxy.rootController.rootDelegate;
      expect(delegate.topRoute, isA<PageRoute>());
      Fluxy.dialog(const Text('dlg'));
      await t.pumpAndSettle();
      expect(delegate.topRoute, isA<PopupRoute>());
      expect(Fluxy.rawRoute, same(delegate.topRoute));
      Fluxy.back(result: 1);
      await t.pumpAndSettle();
      expect(delegate.topRoute, isA<PageRoute>());
      Fluxy.toNamed('/item/1');
      await t.pumpAndSettle();
      expect(delegate.topRoute?.settings.name, isNot('/'));
      Fluxy.back();
      await t.pumpAndSettle();
      expect(delegate.topRoute, isA<PageRoute>());
    });

    testWidgets('back(result:) still hands a dialog its result', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final f = Fluxy.dialog<int>(const Text('dlg'));
      await t.pumpAndSettle();
      Fluxy.back(result: 7);
      await t.pumpAndSettle();
      expect(await f, 7);
    });

    testWidgets('an unknown navigator id is a FlutterError', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(() => Fluxy.toNamed('/item/1', id: 'nope'), throwsFlutterError);
    });

    testWidgets('offAll keeps the routeName it was given', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      Fluxy.offAll(() => const Detail(1), routeName: '/detail-one');
      await t.pumpAndSettle();
      expect(locations(), ['/detail-one']);
    });

    testWidgets('off replaces a page of the same type', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      Fluxy.to(() => const Detail(1));
      await t.pumpAndSettle();
      Fluxy.off(() => const Detail(2));
      await t.pumpAndSettle();
      expect(find.text('detail 2'), findsOneWidget);
      expect(locations(), ['/', '/Detail']);
    });
  });
}
