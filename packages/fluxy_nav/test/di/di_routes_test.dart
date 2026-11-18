// Dependencies and routes (DI-PLAN.md phase 0): what the BOOFI app relies
// on, and the route-linked bugs B1, B6, B7, skipped until fixed.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:material_ui/material_ui.dart';

class Counter extends FluxyController {
  Counter([this.n = 0]);
  final int n;
  final count = 0.obs;
  int inits = 0;
  int readies = 0;
  int closes = 0;
  bool workerDisposed = false;

  @override
  void onInit() {
    super.onInit();
    inits++;
    own(ever(count, (_) {}));
    onDispose(() => workerDisposed = true);
  }

  @override
  void onReady() => readies++;

  @override
  void onClose() {
    closes++;
    super.onClose();
  }
}

class PageCtrl extends FluxyController {
  int closes = 0;
  @override
  void onClose() {
    closes++;
    super.onClose();
  }
}

// The BOOFI pattern: `final CTRL = Fluxy.put(Controller());` at the top
// level, created on first access.
Counter? _global;
Counter get ctrl => _global ??= Fluxy.put<Counter>(Counter());

class UsesCtrl extends StatelessWidget {
  const UsesCtrl({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Obx(() => Text('count ${ctrl.count.value}')));
}

class PageBinding extends Binding {
  @override
  List<Bind> dependencies() => [Bind.lazyPut(() => PageCtrl())];
}

class PutBinding implements BindingsInterface<void> {
  @override
  void dependencies() {
    Fluxy.put(PageCtrl());
  }
}

Widget app({String home = '/'}) => FluxyApp(
  initialRoute: home,
  getPages: [
    FluxyPage(name: '/', page: () => const UsesCtrl()),
    FluxyPage(name: '/plain', page: () => const Scaffold(body: Text('plain'))),
    FluxyPage(name: '/uses', page: () => const UsesCtrl()),
    FluxyPage(
      name: '/bound',
      binding: PageBinding(),
      page: () => Scaffold(body: Text('bound ${Fluxy.find<PageCtrl>().closes}')),
    ),
    FluxyPage(
      name: '/put-bound',
      binding: PutBinding(),
      page: () => Scaffold(body: Text('put ${Fluxy.find<PageCtrl>().closes}')),
    ),
  ],
);

void main() {
  tearDown(() {
    _global = null;
    Fluxy.reset();
  });

  group('lifecycle', () {
    testWidgets('onInit once, onReady after the frame, own() disposed on delete',
        (t) async {
      await t.pumpWidget(app(home: '/plain'));
      await t.pumpAndSettle();
      final c = Fluxy.put(Counter());
      expect(c.inits, 1);
      expect(c.readies, 0);
      await t.pump();
      expect(c.readies, 1);
      expect(Fluxy.find<Counter>(), same(c));
      expect(c.inits, 1);
      Fluxy.delete<Counter>();
      expect(c.closes, 1);
      expect(c.workerDisposed, isTrue);
      expect(c.isClosed, isTrue);
      Fluxy.delete<Counter>();
      expect(c.closes, 1);
    });
  });

  group('page bindings', () {
    testWidgets('a Binding page closes its dependencies when it goes', (
      t,
    ) async {
      await t.pumpWidget(app(home: '/plain'));
      await t.pumpAndSettle();
      Fluxy.toNamed('/bound');
      await t.pumpAndSettle();
      final c = Fluxy.find<PageCtrl>();
      expect(find.text('bound 0'), findsOneWidget);
      Fluxy.back();
      await t.pumpAndSettle();
      expect(c.closes, 1);
      expect(Fluxy.isRegistered<PageCtrl>(), isFalse);
    });

    testWidgets('a put inside a binding lives as long as the page', (t) async {
      await t.pumpWidget(app(home: '/plain'));
      await t.pumpAndSettle();
      Fluxy.toNamed('/put-bound');
      await t.pumpAndSettle();
      final c = Fluxy.find<PageCtrl>();
      Fluxy.back();
      await t.pumpAndSettle();
      expect(c.closes, 1);
      expect(Fluxy.isRegistered<PageCtrl>(), isFalse);
    });
  });

  group('B1: a put lives as long as the app', () {
    testWidgets('first used on a page that is popped', (t) async {
      await t.pumpWidget(app(home: '/plain'));
      await t.pumpAndSettle();
      Fluxy.toNamed('/uses');
      await t.pumpAndSettle();
      final c = ctrl;
      Fluxy.back();
      await t.pumpAndSettle();
      expect(c.isClosed, isFalse);
      expect(Fluxy.find<Counter>(), same(c));
    }, skip: true); // B1

    testWidgets('first used inside a dialog', (t) async {
      await t.pumpWidget(app(home: '/plain'));
      await t.pumpAndSettle();
      Fluxy.dialog(Builder(builder: (_) => Text('n ${ctrl.n}')));
      await t.pumpAndSettle();
      final c = ctrl;
      Fluxy.back();
      await t.pumpAndSettle();
      expect(c.isClosed, isFalse);
      expect(c.workerDisposed, isFalse);
    }, skip: true); // B1

    testWidgets('first used on the root page, then offAllNamed', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final c = ctrl;
      Fluxy.offAllNamed('/plain');
      await t.pumpAndSettle();
      expect(c.isClosed, isFalse);
      Fluxy.offAllNamed('/');
      await t.pumpAndSettle();
      expect(ctrl, same(c));
      ctrl.count.value++;
      await t.pump();
      expect(find.text('count 1'), findsOneWidget);
    }, skip: true); // B1
  });

  testWidgets('B7: a lazyPut found on a page stays registered', (t) async {
    Fluxy.lazyPut(() => Counter(3));
    await t.pumpWidget(app(home: '/plain'));
    await t.pumpAndSettle();
    Fluxy.toNamed('/uses');
    await t.pumpAndSettle();
    Fluxy.find<Counter>();
    Fluxy.back();
    await t.pumpAndSettle();
    expect(Fluxy.isRegistered<Counter>(), isTrue);
    expect(Fluxy.find<Counter>().n, 3);
  }, skip: true); // B7

  testWidgets('B6: a shared FluxyBuilder controller stays while one shows it', (
    t,
  ) async {
    final show = true.obs;
    await t.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Obx(
              () => show.value
                  ? FluxyBuilder<Counter>(
                      init: Counter(1),
                      builder: (c) => Text('a ${c.n}'),
                    )
                  : const SizedBox(),
            ),
            FluxyBuilder<Counter>(
              init: Counter(2),
              builder: (c) => Text('b ${c.n}'),
            ),
          ],
        ),
      ),
    );
    final c = Fluxy.find<Counter>();
    show.value = false;
    await t.pump();
    expect(c.isClosed, isFalse);
    expect(Fluxy.isRegistered<Counter>(), isTrue);
  }, skip: true); // B6
}
