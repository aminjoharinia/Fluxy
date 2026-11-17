import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy/fluxy.dart';
import 'package:material_ui/material_ui.dart';

import 'package:example_nav2/main.dart' as app;

void main() {
  Future<void> close(WidgetTester tester) async {
    // Unmount the app so the dashboard controller closes and its clock stops.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    Fluxy.reset();
  }

  testWidgets('/home opens the dashboard in the nested outlet', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DashboardView is working'), findsOneWidget);
    expect(Fluxy.currentRoute, '/home');
    await close(tester);
  });

  testWidgets('the bottom bar switches the home outlet', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Products'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(Fluxy.currentRoute, '/home/products');
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('DashboardView is working'), findsNothing);
    await close(tester);
  });
}
