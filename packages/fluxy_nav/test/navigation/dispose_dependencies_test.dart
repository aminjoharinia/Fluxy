import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
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
