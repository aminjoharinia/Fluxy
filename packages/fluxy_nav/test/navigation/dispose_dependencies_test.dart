import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'utils/wrapper.dart';

void main() {
  testWidgets("Test dispose dependencies with unnamed routes", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    expect(Fluxy.isRegistered<Controller2>(), false);
    expect(Fluxy.isRegistered<Controller>(), false);

    Fluxy.to(() => const First());

    await tester.pumpAndSettle();

    expect(find.byType(First), findsOneWidget);

    expect(Fluxy.isRegistered<Controller>(), true);

    Fluxy.to(() => const Second());

    await tester.pumpAndSettle();

    expect(find.byType(Second), findsOneWidget);

    expect(Fluxy.isRegistered<Controller>(), true);
    expect(Fluxy.isRegistered<Controller2>(), true);

    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(First), findsOneWidget);

    expect(Fluxy.isRegistered<Controller>(), true);
    expect(Fluxy.isRegistered<Controller2>(), false);

    Fluxy.back();

    await tester.pumpAndSettle();

    expect(Fluxy.isRegistered<Controller>(), false);
    expect(Fluxy.isRegistered<Controller2>(), false);
  });
}

class Controller extends FluxyController {}

class Controller2 extends FluxyController {}

class First extends StatelessWidget {
  const First({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.put(Controller());
    return const Center(
      child: Text("first"),
    );
  }
}

class Second extends StatelessWidget {
  const Second({super.key});

  @override
  Widget build(BuildContext context) {
    Fluxy.put(Controller2());
    return const Center(
      child: Text("second"),
    );
  }
}
