import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

// APP-NOTES 2 and 10: Fluxy.backToFirst() and the nullable Fluxy.navigator.
void main() {
  testWidgets('backToFirst closes dialogs and sheets, then pops to the first page',
      (tester) async {
    await tester.pumpWidget(FluxyApp(home: const Text('home')));
    Fluxy.to(() => const Text('second'));
    await tester.pumpAndSettle();
    Fluxy.to(() => const Text('third'));
    await tester.pumpAndSettle();
    Fluxy.bottomSheet(const Material(child: Text('sheet')));
    await tester.pumpAndSettle();
    Fluxy.dialog(const Material(child: Text('dialog')));
    await tester.pumpAndSettle();
    expect(Fluxy.isDialogOpen, isTrue);
    expect(Fluxy.isBottomSheetOpen, isTrue);

    Fluxy.backToFirst();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    for (final gone in ['second', 'third', 'sheet', 'dialog']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(Fluxy.isDialogOpen, isFalse);
    expect(Fluxy.isBottomSheetOpen, isFalse);
  });

  testWidgets('backToFirst on the first page does nothing', (tester) async {
    await tester.pumpWidget(FluxyApp(home: const Text('home')));
    Fluxy.backToFirst();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(Fluxy.navigator?.canPop(), isFalse);
  });

  testWidgets('Fluxy.navigator is null without an app, the root navigator with one',
      (tester) async {
    await tester.pumpWidget(const Text('no app', textDirection: TextDirection.ltr));
    expect(Fluxy.navigator, isNull);
    expect(navigator, isNull);

    await tester.pumpWidget(FluxyApp(home: const Text('home')));
    expect(Fluxy.navigator, same(Fluxy.key.currentState));
    expect(navigator, same(Fluxy.key.currentState));
  });
}
