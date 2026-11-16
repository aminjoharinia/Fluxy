import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'utils/wrapper.dart';

void main() {
  testWidgets("Get.bottomSheet smoke test", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    await tester.pump();

    Fluxy.bottomSheet(Wrap(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.music_note),
          title: const Text('Music'),
          onTap: () {},
        ),
      ],
    ));

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  testWidgets("Get.bottomSheet close test", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    await tester.pump();

    Fluxy.bottomSheet(Wrap(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.music_note),
          title: const Text('Music'),
          onTap: () {},
        ),
      ],
    ));

    await tester.pumpAndSettle();

    expect(Fluxy.isBottomSheetOpen, true);

    Fluxy.backLegacy();
    await tester.pumpAndSettle();

    expect(Fluxy.isBottomSheetOpen, false);

    // expect(() => Fluxy.bottomSheet(Container(), isScrollControlled: null),
    //     throwsAssertionError);

    // expect(() => Fluxy.bottomSheet(Container(), isDismissible: null),
    //     throwsAssertionError);

    // expect(() => Fluxy.bottomSheet(Container(), enableDrag: null),
    //     throwsAssertionError);

    await tester.pumpAndSettle();
  });

  // testWidgets(
  //   "FluxyApp with debugShowMaterialGrid null",
  //   (tester) async {
  //     expect(
  //       () => FluxyApp(
  //         debugShowMaterialGrid: null,
  //       ),
  //       throwsAssertionError,
  //     );
  //   },
  // );
}
