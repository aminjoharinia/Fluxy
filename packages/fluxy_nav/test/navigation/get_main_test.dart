import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'utils/wrapper.dart';

void main() {
  testWidgets("Get.to navigates to provided route", (tester) async {
    await tester.pumpWidget(Wrapper(child: Container()));

    Fluxy.to(() => const FirstScreen());

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  testWidgets("Get.toNamed navigates to provided named route", (tester) async {
    await tester.pumpWidget(FluxyApp(
      initialRoute: '/first',
      getPages: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.toNamed('/second');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("unknowroute", (tester) async {
    await tester.pumpWidget(FluxyApp(
      initialRoute: '/first',
      unknownRoute: FluxyPage(name: '/404', page: () => const Scaffold()),
      getPages: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.toNamed('/secondd');

    await tester.pumpAndSettle();

    expect(Fluxy.rootController.rootDelegate.currentConfiguration?.route?.name,
        '/404');
  });

  testWidgets("Get.off navigates to provided route", (tester) async {
    await tester.pumpWidget(const Wrapper(child: FirstScreen()));
    // await tester.pump();

    Fluxy.off(() => const SecondScreen());

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("Get.off removes current route", (tester) async {
    await tester.pumpWidget(const Wrapper(child: FirstScreen()));
    await tester.pump();

    Fluxy.off(() => const SecondScreen());
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsNothing);
  });

  testWidgets("Get.offNamed navigates to provided named route", (tester) async {
    await tester.pumpWidget(FluxyApp(
      initialRoute: '/first',
      getPages: [
        FluxyPage(name: '/first', page: () => const FirstScreen()),
        FluxyPage(name: '/second', page: () => const SecondScreen()),
        FluxyPage(name: '/third', page: () => const ThirdScreen()),
      ],
    ));

    await tester.pump();

    Fluxy.offNamed('/second');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("Get.offNamed removes current route", (tester) async {
    await tester.pumpWidget(FluxyApp(
      initialRoute: '/first',
      getPages: [
        FluxyPage(name: '/first', page: () => const FirstScreen()),
        FluxyPage(name: '/second', page: () => const SecondScreen()),
        FluxyPage(name: '/third', page: () => const ThirdScreen()),
      ],
    ));

    await tester.pump();

    Fluxy.offNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsNothing);
  });

  testWidgets("Get.offNamed removes only current route", (tester) async {
    await tester.pumpWidget(FluxyApp(
      initialRoute: '/first',
      getPages: [
        FluxyPage(name: '/first', page: () => const FirstScreen()),
        FluxyPage(name: '/second', page: () => const SecondScreen()),
        FluxyPage(name: '/third', page: () => const ThirdScreen()),
      ],
    ));

    // await tester.pump();

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.offNamed('/third');
    await tester.pumpAndSettle();
    Fluxy.back();
    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets("Get.offAll navigates to provided route", (tester) async {
    await tester.pumpWidget(const Wrapper(child: FirstScreen()));
    await tester.pump();

    Fluxy.offAll(() => const SecondScreen());

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("Get.offAll removes all previous routes", (tester) async {
    await tester.pumpWidget(const Wrapper(child: FirstScreen()));
    await tester.pump();

    Fluxy.to(() => const SecondScreen());
    await tester.pumpAndSettle();
    Fluxy.offAll(() => const ThirdScreen());
    await tester.pumpAndSettle();
    Fluxy.back();
    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsNothing);

    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsNothing);
  });

  testWidgets("Get.offAllNamed navigates to provided named route",
      (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    await tester.pump();

    Fluxy.toNamed('/second');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("Get.offAllNamed removes all previous routes", (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    await tester.pump();

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.offAllNamed('/third');
    await tester.pumpAndSettle();
    Fluxy.back();
    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsNothing);

    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsNothing);
  });

  testWidgets("Get.offAndToNamed navigates to provided route", (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.offAndToNamed('/second');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets("Get.offAndToNamed removes previous route", (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.offAndToNamed('/second');

    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsNothing);
  });

  testWidgets("Get.offUntil navigates to provided route", (tester) async {
    await tester.pumpWidget(Wrapper(child: Container()));

    Fluxy.to(() => const FirstScreen());

    await tester.pumpAndSettle();

    Fluxy.offUntil(
        () => const ThirdScreen(), (route) => route.name == '/FirstScreen');

    await tester.pumpAndSettle();

    expect(find.byType(ThirdScreen), findsOneWidget);
  });

  testWidgets("Get.until removes each route that meet the predicate",
      (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();

    Fluxy.toNamed('/third');
    await tester.pumpAndSettle();

    Fluxy.until((route) => route.name == '/first');

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
    expect(find.byType(SecondScreen), findsNothing);
    expect(find.byType(ThirdScreen), findsNothing);
  });

  testWidgets(
      "Get.offUntil removes previous routes if they don't match predicate",
      (tester) async {
    await tester.pumpWidget(Wrapper(child: Container()));

    Fluxy.to(() => const FirstScreen());
    await tester.pumpAndSettle();
    Fluxy.to(() => const SecondScreen());
    await tester.pumpAndSettle();
    Fluxy.offUntil(
        () => const ThirdScreen(), (route) => route.name == '/FirstScreen');
    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsNothing);
  });

  testWidgets(
      "Get.offUntil leaves previous routes that match provided predicate",
      (tester) async {
    await tester.pumpWidget(Wrapper(child: Container()));

    Fluxy.to(() => const FirstScreen());
    await tester.pumpAndSettle();
    Fluxy.to(() => const SecondScreen());
    await tester.pumpAndSettle();
    Fluxy.offUntil(
        () => const ThirdScreen(), (route) => route.name == '/FirstScreen');
    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  group('Get.offNamedUntil Tests', () {
    testWidgets("Navigates to provided route", (tester) async {
      await tester.pumpWidget(WrapperNamed(
        initialRoute: '/first',
        namedRoutes: [
          FluxyPage(page: () => const FirstScreen(), name: '/first'),
          FluxyPage(page: () => const SecondScreen(), name: '/second'),
          FluxyPage(page: () => const ThirdScreen(), name: '/third')
        ],
      ));

      Fluxy.offNamedUntil('/second', (route) => route.name == '/first');
      await tester.pumpAndSettle();

      expect(find.byType(SecondScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/second');
    });

    testWidgets("Removes routes that don't match predicate", (tester) async {
      await tester.pumpWidget(WrapperNamed(
        initialRoute: '/first',
        namedRoutes: [
          FluxyPage(page: () => const FirstScreen(), name: '/first'),
          FluxyPage(page: () => const SecondScreen(), name: '/second'),
          FluxyPage(page: () => const ThirdScreen(), name: '/third')
        ],
      ));

      Fluxy.toNamed('/second');
      await tester.pumpAndSettle();
      Fluxy.offNamedUntil('/third', (route) => route.name == '/first');
      await tester.pumpAndSettle();

      expect(find.byType(ThirdScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/third');
      expect(Fluxy.previousRoute, '/first');
    });

    testWidgets("Keeps routes that match predicate", (tester) async {
      await tester.pumpWidget(WrapperNamed(
        initialRoute: '/first',
        namedRoutes: [
          FluxyPage(page: () => const FirstScreen(), name: '/first'),
          FluxyPage(page: () => const SecondScreen(), name: '/second'),
          FluxyPage(page: () => const ThirdScreen(), name: '/third'),
        ],
      ));

      Fluxy.toNamed('/second');
      await tester.pumpAndSettle();
      Fluxy.offNamedUntil('/third', (route) => route.name == '/first');
      await tester.pumpAndSettle();
      Fluxy.back();
      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/first');
    });

    testWidgets("Handles predicate that never returns true", (tester) async {
      await tester.pumpWidget(WrapperNamed(
        initialRoute: '/first',
        namedRoutes: [
          FluxyPage(page: () => const FirstScreen(), name: '/first'),
          FluxyPage(page: () => const SecondScreen(), name: '/second'),
          FluxyPage(page: () => const ThirdScreen(), name: '/third'),
          FluxyPage(page: () => const FourthScreen(), name: '/fourth'),
        ],
      ));

      Fluxy.toNamed('/second');
      await tester.pumpAndSettle();

      Fluxy.toNamed('/third');
      await tester.pumpAndSettle();

      Fluxy.offNamedUntil('/fourth', (route) => false);
      await tester.pumpAndSettle();

      expect(find.byType(FourthScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/fourth');
      expect(Fluxy.previousRoute, '/first');
    });

    testWidgets("Handles complex navigation scenario", (tester) async {
      await tester.pumpWidget(WrapperNamed(
        initialRoute: '/first',
        namedRoutes: [
          FluxyPage(page: () => const FirstScreen(), name: '/first'),
          FluxyPage(page: () => const SecondScreen(), name: '/second'),
          FluxyPage(page: () => const ThirdScreen(), name: '/third'),
          FluxyPage(page: () => const FourthScreen(), name: '/fourth'),
        ],
      ));

      Fluxy.toNamed('/second');
      await tester.pumpAndSettle();
      Fluxy.toNamed('/third');
      await tester.pumpAndSettle();
      Fluxy.offNamedUntil('/fourth', (route) => route.name == '/first');
      await tester.pumpAndSettle();

      expect(find.byType(FourthScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/fourth');
      expect(Fluxy.previousRoute, '/first');

      Fluxy.back();
      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
      expect(Fluxy.currentRoute, '/first');
    });
  });

  testWidgets("Get.offNamedUntil navigates to provided route", (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.offNamedUntil('/second', (route) => route.name == '/first');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsOneWidget);
  });

  testWidgets(
      "Get.offNamedUntil removes previous routes if they don't match predicate",
      (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.offNamedUntil('/third', (route) => route.name == '/first');

    await tester.pumpAndSettle();

    expect(find.byType(SecondScreen), findsNothing);
  });

  testWidgets(
      "Get.offNamedUntil leaves previous routes that match provided predicate",
      (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third'),
      ],
    ));

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.offNamedUntil('/third', (route) => route.name == '/first');
    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  testWidgets("Get.back navigates back", (tester) async {
    await tester.pumpWidget(
      Wrapper(
        defaultTransition: Transition.circularReveal,
        child: Container(),
      ),
    );

    // await tester.pump();

    Fluxy.to(() => const FirstScreen());
    await tester.pumpAndSettle();

    Fluxy.to(() => const SecondScreen());
    await tester.pumpAndSettle();
    Fluxy.back();

    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  testWidgets(
      "Get.back with closeOverlays pops both snackbar and current route",
      (tester) async {
    await tester.pumpWidget(
      Wrapper(
        defaultTransition: Transition.circularReveal,
        child: Container(),
      ),
    );

    // await tester.pump();

    Fluxy.to(() => const FirstScreen());
    await tester.pumpAndSettle();
    Fluxy.to(() => const SecondScreen());
    await tester.pumpAndSettle();
    Fluxy.snackbar('title', "message");
    await tester.pumpAndSettle();
    Fluxy.backLegacy(closeOverlays: true);

    await tester.pumpAndSettle();

    expect(Fluxy.isSnackbarOpen, false);

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  testWidgets("Get.until", (tester) async {
    await tester.pumpWidget(WrapperNamed(
      initialRoute: '/first',
      namedRoutes: [
        FluxyPage(page: () => const FirstScreen(), name: '/first'),
        FluxyPage(page: () => const SecondScreen(), name: '/second'),
        FluxyPage(page: () => const ThirdScreen(), name: '/third')
      ],
    ));

    await tester.pump();

    Fluxy.toNamed('/second');
    await tester.pumpAndSettle();
    Fluxy.toNamed('/third');
    await tester.pumpAndSettle();
    Fluxy.until((route) => route.name == '/first');
    await tester.pumpAndSettle();

    expect(find.byType(FirstScreen), findsOneWidget);
  });

  group("Get.defaultTransition smoke test", () {
    testWidgets("fadeIn", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.fadeIn,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("downToUp", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.downToUp,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("fade", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.fade,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("leftToRight", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.leftToRight,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("leftToRightWithFade", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.leftToRightWithFade,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("leftToRightWithFade", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.rightToLeft,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("defaultTransition", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.rightToLeft,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("rightToLeftWithFade", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.rightToLeftWithFade,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("cupertino", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.cupertino,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });

    testWidgets("size", (tester) async {
      await tester.pumpWidget(
        Wrapper(
          defaultTransition: Transition.size,
          child: Container(),
        ),
      );

      Fluxy.to(() => const FirstScreen());

      await tester.pumpAndSettle();

      expect(find.byType(FirstScreen), findsOneWidget);
    });
  });
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_unnecessary_containers
    return Container(child: const Text('Home'));
  }
}

class FirstScreen extends StatelessWidget {
  const FirstScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_unnecessary_containers
    return Container(child: const Text('FirstScreen'));
  }
}

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class ThirdScreen extends StatelessWidget {
  const ThirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class FourthScreen extends StatelessWidget {
  const FourthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
