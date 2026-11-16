import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

void main() {
  test('Parse Page with children', () {
    final testParams = {'hi': 'value'};
    final pageTree = GetPage(
      name: '/city',
      page: () => Container(),
      children: [
        GetPage(
          name: '/home',
          page: () => Container(),
          transition: Transition.rightToLeftWithFade,
          children: [
            GetPage(
              name: '/bed-room',
              transition: Transition.size,
              page: () => Container(),
            ),
            GetPage(
              name: '/living-room',
              transition: Transition.topLevel,
              page: () => Container(),
            ),
          ],
        ),
        GetPage(
          name: '/work',
          transition: Transition.upToDown,
          page: () => Container(),
          children: [
            GetPage(
              name: '/office',
              transition: Transition.zoom,
              page: () => Container(),
              children: [
                GetPage(
                  name: '/pen',
                  transition: Transition.cupertino,
                  page: () => Container(),
                  parameters: testParams,
                ),
                GetPage(
                  name: '/paper',
                  page: () => Container(),
                  transition: Transition.downToUp,
                ),
              ],
            ),
            GetPage(
              name: '/meeting-room',
              transition: Transition.fade,
              page: () => Container(),
            ),
          ],
        ),
      ],
    );

    final tree = ParseRouteTree(routes: <GetPage>[]);

    tree.addRoute(pageTree);

    // tree.addRoute(pageTree);
    const searchRoute = '/city/work/office/pen';
    final match = tree.matchRoute(searchRoute);
    expect(match, isNotNull);
    expect(match.route!.name, searchRoute);
    final testRouteParam = match.route!.parameters!;
    for (final tParam in testParams.entries) {
      expect(testRouteParam[tParam.key], tParam.value);
    }
  });

  test('Parse Page without children', () {
    final pageTree = [
      GetPage(
          name: '/city',
          page: () => Container(),
          transition: Transition.cupertino),
      GetPage(
          name: '/city/home',
          page: () => Container(),
          transition: Transition.downToUp),
      GetPage(
          name: '/city/home/bed-room',
          page: () => Container(),
          transition: Transition.fade),
      GetPage(
          name: '/city/home/living-room',
          page: () => Container(),
          transition: Transition.fadeIn),
      GetPage(
          name: '/city/work',
          page: () => Container(),
          transition: Transition.leftToRight),
      GetPage(
          name: '/city/work/office',
          page: () => Container(),
          transition: Transition.leftToRightWithFade),
      GetPage(
          name: '/city/work/office/pen',
          page: () => Container(),
          transition: Transition.native),
      GetPage(
          name: '/city/work/office/paper',
          page: () => Container(),
          transition: Transition.noTransition),
      GetPage(
          name: '/city/work/meeting-room',
          page: () => Container(),
          transition: Transition.rightToLeft),
    ];

    final tree = ParseRouteTree(routes: pageTree);

    // for (var p in pageTree) {
    //   tree.addRoute(p);
    // }

    const searchRoute = '/city/work/office/pen';
    final match = tree.matchRoute(searchRoute);
    expect(match, isNotNull);
    expect(match.route!.name, searchRoute);
  });

  testWidgets(
    'test params from dynamic route',
    (tester) async {
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/first/juan',
        getPages: [
          GetPage(page: () => Container(), name: '/first/:name'),
          GetPage(page: () => Container(), name: '/second/:id'),
          GetPage(page: () => Container(), name: '/third'),
          GetPage(page: () => Container(), name: '/last/:id/:name/profile'),
          GetPage(page: () => Container(), name: '/first/second/:token')
        ],
      ));

      expect(Get.parameters['name'], 'juan');

      Get.toNamed('/second/1234');

      await tester.pumpAndSettle();

      expect(Get.parameters['id'], '1234');

      Get.toNamed('/third?name=jonny&job=dev');

      await tester.pumpAndSettle();

      expect(Get.parameters['name'], 'jonny');
      expect(Get.parameters['job'], 'dev');

      Get.toNamed('/last/1234/ana/profile');

      await tester.pumpAndSettle();

      expect(Get.parameters['id'], '1234');
      expect(Get.parameters['name'], 'ana');

      Get.toNamed('/last/1234/ana/profile?job=dev');

      await tester.pumpAndSettle();

      expect(Get.parameters['id'], '1234');
      expect(Get.parameters['name'], 'ana');
      expect(Get.parameters['job'], 'dev');

      Get.toNamed(
        'https://www.example.com/first/second/fa9662f4-ec3f-11ee-a806-169a3915b383',
      );
      await tester.pumpAndSettle();
      expect(Get.parameters['token'], 'fa9662f4-ec3f-11ee-a806-169a3915b383');
    },
  );

  testWidgets(
    'params in url by parameters',
    (tester) async {
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/first/juan',
        getPages: [
          GetPage(page: () => Container(), name: '/first/:name'),
          GetPage(page: () => Container(), name: '/italy'),
        ],
      ));

      // Get.parameters = ({"varginias": "varginia", "vinis": "viniiss"});
      var parameters = <String, String>{
        "varginias": "varginia",
        "vinis": "viniiss"
      };
      // print("Get.parameters: ${Get.parameters}");
      parameters.addAll({"a": "b", "c": "d"});
      Get.toNamed("/italy", parameters: parameters);

      await tester.pumpAndSettle();
      expect(Get.parameters['varginias'], 'varginia');
      expect(Get.parameters['vinis'], 'viniiss');
      expect(Get.parameters['a'], 'b');
      expect(Get.parameters['c'], 'd');
    },
  );

  test('copyWith with a new name matches the new pattern', () {
    final page = GetPage(name: '/user/:id', page: () => Container());
    final copy = page.copyWith(name: '/shop/:item');
    expect(copy.path.keys, ['item']);
    expect(copy.path.regex.hasMatch('/shop/42'), isTrue);
    expect(copy.path.regex.hasMatch('/user/42'), isFalse);
    expect(page.copyWith(title: 't').path.keys, ['id']);
  });

  test('matched pages carry the path key and the parameters', () {
    final tree = ParseRouteTree(routes: []);
    tree.addRoutes([
      GetPage(name: '/', page: () => Container()),
      GetPage(name: '/user/:id', page: () => Container()),
    ]);
    final decoded = tree.matchRoute('/user/7?tab=a');
    final last = decoded.currentTreeBranch.last;
    expect(last.key, const ValueKey('/user/7'));
    expect(last.name, '/user/7');
    expect(last.parameters, {'id': '7', 'tab': 'a'});
  });
}
