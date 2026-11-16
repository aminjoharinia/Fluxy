import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

void main() {
  Fluxy.lazyPut<Controller2>(() => Controller2());
  testWidgets("GetxController smoke test", (test) async {
    await test.pumpWidget(
      MaterialApp(
        home: FluxyBuilder<Controller>(
          init: Controller(),
          builder: (controller) => Column(
            children: [
              Text(
                '${controller.counter}',
              ),
              TextButton(
                child: const Text("increment"),
                onPressed: () => controller.increment(),
              ),
              TextButton(
                child: const Text("incrementWithId"),
                onPressed: () => controller.incrementWithId(),
              ),
              FluxyBuilder<Controller>(
                  id: '1',
                  didChangeDependencies: (_) {
                    // print("didChangeDependencies called");
                  },
                  builder: (controller) {
                    return Text('id ${controller.counter}');
                  }),
              FluxyBuilder<Controller2>(builder: (controller) {
                return Text('lazy ${controller.test}');
              }),
              FluxyBuilder<ControllerNonGlobal>(
                  init: ControllerNonGlobal(),
                  global: false,
                  builder: (controller) {
                    return Text('single ${controller.nonGlobal}');
                  })
            ],
          ),
        ),
      ),
    );

    expect(find.text("0"), findsOneWidget);

    Controller.to.increment();

    await test.pump();

    expect(find.text("1"), findsOneWidget);

    await test.tap(find.text('increment'));

    await test.pump();

    expect(find.text("2"), findsOneWidget);

    await test.tap(find.text('incrementWithId'));

    await test.pump();

    expect(find.text("id 3"), findsOneWidget);
    expect(find.text("lazy 0"), findsOneWidget);
    expect(find.text("single 0"), findsOneWidget);
  });

  // testWidgets(
  //   "MixinBuilder with build null",
  //   (test) async {
  //     expect(
  //       () => FluxyBuilder<Controller>(
  //         init: Controller(),
  //         builder: null,
  //       ),
  //       throwsAssertionError,
  //     );
  //   },
  // );
}

class Controller extends FluxyController {
  static Controller get to => Fluxy.find();

  int counter = 0;

  void increment() {
    counter++;
    update();
  }

  void incrementWithId() {
    counter++;
    update(['1']);
  }
}

class Controller2 extends FluxyController {
  int test = 0;
}

class ControllerNonGlobal extends FluxyController {
  int nonGlobal = 0;
}
