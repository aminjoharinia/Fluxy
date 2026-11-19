import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // A widget test that pumps the app once must end with no timer pending
  // (onReady used to run from a Future, a zero-length timer).
  testWidgets('one pump of FluxyApp leaves no timer; onReady after the frame',
      (tester) async {
    var ready = 0;
    await tester.pumpWidget(FluxyApp(
      onReady: () => ready++,
      home: const SizedBox(),
    ));
    expect(ready, 1);
  });

  testWidgets('onReady runs once, not again when the app goes away',
      (tester) async {
    var ready = 0;
    await tester.pumpWidget(FluxyApp(
      onReady: () => ready++,
      home: const SizedBox(),
    ));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(ready, 1);
  });
}
