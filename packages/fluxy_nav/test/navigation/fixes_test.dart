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
}
