import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'get_main_test.dart';

class RedirectMiddleware extends FluxyMiddleware {
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    return RouteDecoder.fromRoute('/second');
  }
}

class Redirect2Middleware extends FluxyMiddleware {
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    return RouteDecoder.fromRoute('/first');
  }
}

class RedirectMiddlewareNull extends FluxyMiddleware {
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    return null;
  }
}

class RedirectBypassMiddleware extends FluxyMiddleware {
  @override
  Future<RouteDecoder?> redirectDelegate(RouteDecoder route) async {
    return route;
  }
}

void main() {
  tearDown(() {
    Fluxy.reset();
  });

  testWidgets("Middleware should redirect to second screen", (tester) async {
    // Test setup
    await tester.pumpWidget(
      FluxyApp(
        initialRoute: '/',
        getPages: [
          FluxyPage(name: '/', page: () => const Home()),
          FluxyPage(
            name: '/first',
            page: () => const FirstScreen(),
            middlewares: [RedirectMiddleware()],
          ),
          FluxyPage(name: '/second', page: () => const SecondScreen()),
          FluxyPage(name: '/third', page: () => const ThirdScreen()),
        ],
      ),
    );

    // Act
    Fluxy.toNamed('/first');
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(SecondScreen), findsOneWidget);
    expect(find.byType(FirstScreen), findsNothing);
    expect(Fluxy.currentRoute, '/second');
  });

  testWidgets("Middleware should stop navigation", (tester) async {
    // Test setup
    await tester.pumpWidget(
      FluxyApp(
        initialRoute: '/',
        getPages: [
          FluxyPage(name: '/', page: () => const Home()),
          FluxyPage(
            name: '/first',
            page: () => const FirstScreen(),
            middlewares: [RedirectMiddlewareNull()],
          ),
          FluxyPage(name: '/second', page: () => const SecondScreen()),
          FluxyPage(name: '/third', page: () => const ThirdScreen()),
        ],
      ),
    );

    // Act
    await tester.pumpAndSettle();
    Fluxy.toNamed('/first');
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(Home), findsOneWidget);
    expect(find.byType(FirstScreen), findsNothing);
    expect(Fluxy.currentRoute, '/');
  });

  testWidgets("Middleware should be bypassed", (tester) async {
    // Test setup
    await tester.pumpWidget(
      FluxyApp(
        initialRoute: '/',
        getPages: [
          FluxyPage(name: '/', page: () => const Home()),
          FluxyPage(
            name: '/first',
            page: () => const FirstScreen(),
            middlewares: [RedirectBypassMiddleware()],
          ),
          FluxyPage(name: '/second', page: () => const SecondScreen()),
          FluxyPage(name: '/third', page: () => const ThirdScreen()),
        ],
      ),
    );

    // Act
    await tester.pumpAndSettle();
    Fluxy.toNamed('/first');
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(FirstScreen), findsOneWidget);
    expect(find.byType(SecondScreen), findsNothing);
    expect(find.byType(Home), findsNothing);
    expect(Fluxy.currentRoute, '/first');
  });

  testWidgets("Middleware should redirect twice", (tester) async {
    // Test setup
    await tester.pumpWidget(
      FluxyApp(
        initialRoute: '/',
        getPages: [
          FluxyPage(name: '/', page: () => const Home()),
          FluxyPage(
            name: '/first',
            page: () => const FirstScreen(),
            middlewares: [RedirectMiddleware()],
          ),
          FluxyPage(name: '/second', page: () => const SecondScreen()),
          FluxyPage(name: '/third', page: () => const ThirdScreen()),
          FluxyPage(
            name: '/fourth',
            page: () => const FourthScreen(),
            middlewares: [Redirect2Middleware()],
          ),
        ],
      ),
    );

    // Act
    Fluxy.toNamed('/fourth');
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(SecondScreen), findsOneWidget);
    expect(find.byType(FirstScreen), findsNothing);
    expect(Fluxy.currentRoute, '/second');
  });

  testWidgets("Navigation history should be correct after redirects",
      (tester) async {
    // Test setup
    await tester.pumpWidget(
      FluxyApp(
        initialRoute: '/',
        getPages: [
          FluxyPage(name: '/', page: () => const Home()),
          FluxyPage(
            name: '/first',
            page: () => const FirstScreen(),
            middlewares: [RedirectMiddleware()],
          ),
          FluxyPage(name: '/second', page: () => const SecondScreen()),
        ],
      ),
    );

    // Act
    Fluxy.toNamed('/first');
    await tester.pumpAndSettle();

    // Assert
    expect(Fluxy.currentRoute, '/second');
    expect(Fluxy.previousRoute, '/');

    // Act: go back
    Fluxy.back();
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(Home), findsOneWidget);
    expect(Fluxy.currentRoute, '/');
  });
}
