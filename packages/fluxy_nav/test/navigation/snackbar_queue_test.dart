import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

void main() {
  testWidgets('closeAllSnackbars does not show the next queued snackbar',
      (t) async {
    await t.pumpWidget(GetMaterialApp(home: const Text('home')));
    await t.pumpAndSettle();
    var secondDone = false;
    Get.snackbar('first', 'm', duration: const Duration(seconds: 5));
    Get.snackbar('second', 'm', duration: const Duration(seconds: 5))
        .future
        .then((_) => secondDone = true);
    await t.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    Get.closeAllSnackbars();
    await t.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsNothing);
    expect(Get.isSnackbarOpen, false);

    // The queue still works afterwards.
    Get.snackbar('third', 'm', duration: const Duration(milliseconds: 500));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('third'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(secondDone, false);
  });
}
