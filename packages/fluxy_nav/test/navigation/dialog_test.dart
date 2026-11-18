import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'utils/wrapper.dart';

void main() {
  testWidgets("Get.defaultDialog smoke test", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    await tester.pump();

    Fluxy.defaultDialog(
        onConfirm: () {}, middleText: "Dialog made in 3 lines of code");

    await tester.pumpAndSettle();

    expect(find.text("Ok"), findsOneWidget);
  });

  testWidgets("Get.dialog smoke test", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    await tester.pump();

    Fluxy.dialog(const YourDialogWidget());

    await tester.pumpAndSettle();

    expect(find.byType(YourDialogWidget), findsOneWidget);
  });

  group("Get dialog close tests", () {
    /// Set up the test by opening a dialog and checking to ensure state is correct
    Future<void> setUpCloseTest(WidgetTester tester) async {
      await tester.pumpWidget(
        Wrapper(child: Container()),
      );

      await tester.pump();

      Fluxy.dialog(const YourDialogWidget());
      await tester.pumpAndSettle();

      expect(find.byType(YourDialogWidget), findsOneWidget);
      expect(Fluxy.isDialogOpen, true);
    }

    /// Tear down the test by checking after closing the dialog
    Future<void> tearDownCloseTest(WidgetTester tester) async {
      await tester.pumpAndSettle();

      expect(find.byType(YourDialogWidget), findsNothing);
      expect(Fluxy.isDialogOpen, false);
      await tester.pumpAndSettle();
    }

    testWidgets("Get dialog close - with back", (tester) async {
      await setUpCloseTest(tester);
      Fluxy.back();
      await tearDownCloseTest(tester);
    });

    testWidgets("Get dialog close - with closeDialog", (tester) async {
      await setUpCloseTest(tester);
      // Close using closeDialog
      Fluxy.closeDialog();
      await tearDownCloseTest(tester);
    });
  });

  group("Get.closeDialog", () {
    testWidgets("Get.closeDialog - closes dialog and returns value",
        (tester) async {
      await tester.pumpWidget(
        Wrapper(child: Container()),
      );

      await tester.pump();

      final result = Fluxy.dialog(const YourDialogWidget());
      await tester.pumpAndSettle();

      expect(find.byType(YourDialogWidget), findsOneWidget);
      expect(Fluxy.isDialogOpen, true);

      const dialogResult = "My dialog result";

      Fluxy.closeDialog(result: dialogResult);
      await tester.pumpAndSettle();

      final returnedResult = await result;
      expect(returnedResult, dialogResult);

      expect(find.byType(YourDialogWidget), findsNothing);
      expect(Fluxy.isDialogOpen, false);
      await tester.pumpAndSettle();
    });

    testWidgets("Get.closeDialog - does not close bottomsheets",
        (tester) async {
      await tester.pumpWidget(
        Wrapper(child: Container()),
      );

      await tester.pump();

      Fluxy.bottomSheet(const YourDialogWidget());
      await tester.pumpAndSettle();

      expect(find.byType(YourDialogWidget), findsOneWidget);
      expect(Fluxy.isDialogOpen, false);

      Fluxy.closeDialog();
      await tester.pumpAndSettle();

      expect(find.byType(YourDialogWidget), findsOneWidget);
    });
  });
}

class YourDialogWidget extends StatelessWidget {
  const YourDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
