import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

class Detail extends StatelessWidget {
  final int id;
  const Detail(this.id, {super.key});

  @override
  Widget build(BuildContext context) => Text('detail $id');
}

List<String?> stack() => Get.rootController.rootDelegate.activePages
    .map((e) => e.route?.name)
    .toList();

Widget app({PreventDuplicateHandlingMode? aMode}) => GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const Text('home')),
        GetPage(
          name: '/a',
          page: () => const Text('a'),
          preventDuplicateHandlingMode:
              aMode ?? PreventDuplicateHandlingMode.reorderRoutes,
        ),
        GetPage(name: '/b', page: () => const Text('b')),
      ],
    );

void main() {
  testWidgets('Get.to with preventDuplicates: false pushes a second page of '
      'the same class, and builds the new one', (t) async {
    await t.pumpWidget(GetMaterialApp(home: const Text('home')));
    await t.pumpAndSettle();
    Get.to(() => const Detail(1), preventDuplicates: false);
    await t.pumpAndSettle();
    Get.to(() => const Detail(2), preventDuplicates: false);
    await t.pumpAndSettle();
    expect(stack().where((n) => n == '/Detail').length, 2);
    expect(find.text('detail 2'), findsOneWidget);
    Get.back();
    await t.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
  });

  testWidgets('Get.toNamed with preventDuplicates: false pushes again',
      (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    Get.toNamed('/a');
    await t.pumpAndSettle();
    Get.toNamed('/a', preventDuplicates: false);
    await t.pumpAndSettle();
    expect(stack(), ['/', '/a', '/a']);
  });

  testWidgets('offAllNamed completes the futures of the removed pages',
      (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    var done = false;
    Get.toNamed('/a')!.then((_) => done = true);
    await t.pumpAndSettle();
    Get.offAllNamed('/b');
    await t.pumpAndSettle();
    expect(done, true);
    expect(stack(), ['/b']);
  });

  testWidgets('offNamedUntil completes the futures of the removed pages',
      (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    var done = false;
    Get.toNamed('/a')!.then((_) => done = true);
    await t.pumpAndSettle();
    Get.offNamedUntil('/b', (route) => route.name == '/');
    await t.pumpAndSettle();
    expect(done, true);
    expect(stack(), ['/', '/b']);
  });

  testWidgets('offNamed completes the future of the replaced page',
      (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    var done = false;
    Get.toNamed('/a')!.then((_) => done = true);
    await t.pumpAndSettle();
    Get.offNamed('/b');
    await t.pumpAndSettle();
    expect(done, true);
  });

  testWidgets('reorderRoutes completes the future of the moved page',
      (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    var done = false;
    Get.toNamed('/a')!.then((_) => done = true);
    await t.pumpAndSettle();
    Get.toNamed('/b');
    await t.pumpAndSettle();
    Get.toNamed('/a');
    await t.pumpAndSettle();
    expect(stack(), ['/', '/b', '/a']);
    expect(done, true);
  });

  testWidgets('popUntilOriginalRoute goes back to the page on the stack',
      (t) async {
    await t.pumpWidget(
        app(aMode: PreventDuplicateHandlingMode.popUntilOriginalRoute));
    await t.pumpAndSettle();
    Get.toNamed('/a');
    await t.pumpAndSettle();
    Get.toNamed('/b');
    await t.pumpAndSettle();
    final again = Get.toNamed('/a');
    await t.pumpAndSettle();
    expect(stack(), ['/', '/a']);
    expect(find.text('a'), findsOneWidget);
    expect(await again, isNull);
  });

  testWidgets('Get.removeRoute removes a page by name', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    var done = false;
    Get.toNamed('/a')!.then((_) => done = true);
    await t.pumpAndSettle();
    Get.toNamed('/b');
    await t.pumpAndSettle();
    Get.removeRoute('/a');
    await t.pumpAndSettle();
    expect(stack(), ['/', '/b']);
    expect(done, true);
  });

  testWidgets('GetPage.copyWith keeps preventDuplicateHandlingMode',
      (t) async {
    final page = GetPage(
      name: '/x',
      page: () => const SizedBox(),
      preventDuplicateHandlingMode: PreventDuplicateHandlingMode.doNothing,
      restorationId: 'r',
    ).copyWith(name: '/y');
    expect(page.preventDuplicateHandlingMode,
        PreventDuplicateHandlingMode.doNothing);
    expect(page.restorationId, 'r');
  });
}
