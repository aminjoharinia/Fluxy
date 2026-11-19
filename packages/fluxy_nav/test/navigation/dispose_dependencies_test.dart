import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'utils/wrapper.dart';

void main() {
  tearDown(Fluxy.reset);

  testWidgets('a put in a build method lives as long as the app', (
    tester,
  ) async {
    await tester.pumpWidget(Wrapper(child: Container()));
    Fluxy.to(() => const First());
    await tester.pumpAndSettle();
    Fluxy.to(() => const Second());
    await tester.pumpAndSettle();
    expect(Fluxy.isRegistered<Controller>(), true);
    expect(Fluxy.isRegistered<Controller2>(), true);

    Fluxy.back();
    await tester.pumpAndSettle();
    Fluxy.back();
    await tester.pumpAndSettle();
    expect(Fluxy.isRegistered<Controller>(), true);
    expect(Fluxy.isRegistered<Controller2>(), true);
  });

  testWidgets('dependencies in a page binding go with the page', (
    tester,
  ) async {
    await tester.pumpWidget(Wrapper(child: Container()));
    Fluxy.to(
      () => const Bound(),
      bindings: [_Binding(() => Fluxy.lazyPut<Controller>(() => Controller()))],
    );
    await tester.pumpAndSettle();
    Fluxy.to(
      () => const Bound2(),
      bindings: [_Binding(() => Fluxy.put<Controller2>(Controller2()))],
    );
    await tester.pumpAndSettle();
    final c2 = Fluxy.find<Controller2>();
    expect(Fluxy.isRegistered<Controller>(), true);

    Fluxy.back();
    await tester.pumpAndSettle();
    expect(c2.isClosed, true);
    expect(Fluxy.isRegistered<Controller2>(), false);
    expect(Fluxy.isRegistered<Controller>(), true);

    Fluxy.back();
    await tester.pumpAndSettle();
    expect(Fluxy.isRegistered<Controller>(), false);
  });

  // Apps put controllers in main() before runApp; an app widget
  // unmounted and mounted again must find them open.
  group('disposing FluxyApp', () {
    testWidgets('keeps root dependencies and translations', (tester) async {
      final c = Fluxy.put(Controller());
      Fluxy.lazyPut<Controller2>(() => Controller2());
      Fluxy.addTranslations({
        'en_US': {'hi': 'Hello'},
      });
      await tester.pumpWidget(FluxyApp(home: const Text('app')));
      await tester.pumpWidget(const SizedBox()); // the app is unmounted
      expect(c.isClosed, false);
      expect(Fluxy.find<Controller>(), same(c));
      expect(Fluxy.isRegistered<Controller2>(), true);
      expect(Fluxy.translations['en_US'], {'hi': 'Hello'});

      await tester.pumpWidget(FluxyApp(home: const Text('again')));
      expect(find.text('again'), findsOneWidget);
      expect(Fluxy.find<Controller>(), same(c));
    });

    testWidgets('closes the scopes of its pages', (tester) async {
      await tester.pumpWidget(FluxyApp(home: const Text('home')));
      Fluxy.to(
        () => const Bound2(),
        bindings: [_Binding(() => Fluxy.put<Controller2>(Controller2()))],
      );
      await tester.pumpAndSettle();
      final c2 = Fluxy.find<Controller2>();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(c2.isClosed, true);
      expect(Fluxy.isRegistered<Controller2>(), false);
    });

    testWidgets('Fluxy.reset still clears everything', (tester) async {
      final c = Fluxy.put(Controller());
      Fluxy.addTranslations({
        'en_US': {'hi': 'Hello'},
      });
      Fluxy.reset();
      expect(c.isClosed, true);
      expect(Fluxy.isRegistered<Controller>(), false);
      expect(Fluxy.translations, isEmpty);
    });
  });
}

class _Binding implements BindingsInterface<void> {
  _Binding(this.register);
  final void Function() register;
  @override
  void dependencies() => register();
}

class Controller extends FluxyController {}

class Controller2 extends FluxyController {}

class First extends StatelessWidget {
  const First({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.put(Controller());
    return const Center(child: Text("first"));
  }
}

class Second extends StatelessWidget {
  const Second({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.put(Controller2());
    return const Center(child: Text("second"));
  }
}

class Bound extends StatelessWidget {
  const Bound({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.find<Controller>();
    return const Center(child: Text("bound"));
  }
}

class Bound2 extends StatelessWidget {
  const Bound2({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.find<Controller2>();
    return const Center(child: Text("bound2"));
  }
}
