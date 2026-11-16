import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

void main() {
  test('Parse Page with children', () {
    final testParams = {'hi': 'value'};
    final pageTree = FluxyPage(
      name: '/city',
      page: () => Container(),
      children: [
        FluxyPage(
          name: '/home',
          page: () => Container(),
          transition: Transition.rightToLeftWithFade,
          children: [
            FluxyPage(
              name: '/bed-room',
              transition: Transition.size,
              page: () => Container(),
            ),
            FluxyPage(
              name: '/living-room',
              transition: Transition.topLevel,
              page: () => Container(),
            ),
          ],
        ),
        FluxyPage(
          name: '/work',
          transition: Transition.upToDown,
          page: () => Container(),
          children: [
            FluxyPage(
              name: '/office',
              transition: Transition.zoom,
              page: () => Container(),
              children: [
                FluxyPage(
                  name: '/pen',
                  transition: Transition.cupertino,
                  page: () => Container(),
                  parameters: testParams,
                ),
                FluxyPage(
                  name: '/paper',
                  page: () => Container(),
                  transition: Transition.downToUp,
                ),
              ],
            ),
            FluxyPage(
              name: '/meeting-room',
              transition: Transition.fade,
              page: () => Container(),
            ),
          ],
        ),
      ],
    );

    final tree = ParseRouteTree(routes: <FluxyPage>[]);

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
      FluxyPage(
          name: '/city',
          page: () => Container(),
          transition: Transition.cupertino),
      FluxyPage(
          name: '/city/home',
          page: () => Container(),
          transition: Transition.downToUp),
      FluxyPage(
          name: '/city/home/bed-room',
          page: () => Container(),
          transition: Transition.fade),
      FluxyPage(
          name: '/city/home/living-room',
          page: () => Container(),
          transition: Transition.fadeIn),
      FluxyPage(
          name: '/city/work',
          page: () => Container(),
          transition: Transition.leftToRight),
      FluxyPage(
          name: '/city/work/office',
          page: () => Container(),
          transition: Transition.leftToRightWithFade),
      FluxyPage(
          name: '/city/work/office/pen',
          page: () => Container(),
          transition: Transition.native),
      FluxyPage(
          name: '/city/work/office/paper',
          page: () => Container(),
          transition: Transition.noTransition),
      FluxyPage(
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
      await tester.pumpWidget(FluxyApp(
        initialRoute: '/first/juan',
        getPages: [
          FluxyPage(page: () => Container(), name: '/first/:name'),
          FluxyPage(page: () => Container(), name: '/second/:id'),
          FluxyPage(page: () => Container(), name: '/third'),
          FluxyPage(page: () => Container(), name: '/last/:id/:name/profile'),
          FluxyPage(page: () => Container(), name: '/first/second/:token')
        ],
      ));

      expect(Fluxy.parameters['name'], 'juan');

      Fluxy.toNamed('/second/1234');

      await tester.pumpAndSettle();

      expect(Fluxy.parameters['id'], '1234');

      Fluxy.toNamed('/third?name=jonny&job=dev');

      await tester.pumpAndSettle();

      expect(Fluxy.parameters['name'], 'jonny');
      expect(Fluxy.parameters['job'], 'dev');

      Fluxy.toNamed('/last/1234/ana/profile');

      await tester.pumpAndSettle();

      expect(Fluxy.parameters['id'], '1234');
      expect(Fluxy.parameters['name'], 'ana');

      Fluxy.toNamed('/last/1234/ana/profile?job=dev');

      await tester.pumpAndSettle();

      expect(Fluxy.parameters['id'], '1234');
      expect(Fluxy.parameters['name'], 'ana');
      expect(Fluxy.parameters['job'], 'dev');

      Fluxy.toNamed(
        'https://www.example.com/first/second/fa9662f4-ec3f-11ee-a806-169a3915b383',
      );
      await tester.pumpAndSettle();
      expect(Fluxy.parameters['token'], 'fa9662f4-ec3f-11ee-a806-169a3915b383');
    },
  );

  testWidgets(
    'params in url by parameters',
    (tester) async {
      await tester.pumpWidget(FluxyApp(
        initialRoute: '/first/juan',
        getPages: [
          FluxyPage(page: () => Container(), name: '/first/:name'),
          FluxyPage(page: () => Container(), name: '/italy'),
        ],
      ));

      // Fluxy.parameters = ({"varginias": "varginia", "vinis": "viniiss"});
      var parameters = <String, String>{
        "varginias": "varginia",
        "vinis": "viniiss"
      };
      // print("Fluxy.parameters: ${Fluxy.parameters}");
      parameters.addAll({"a": "b", "c": "d"});
      Fluxy.toNamed("/italy", parameters: parameters);

      await tester.pumpAndSettle();
      expect(Fluxy.parameters['varginias'], 'varginia');
      expect(Fluxy.parameters['vinis'], 'viniiss');
      expect(Fluxy.parameters['a'], 'b');
      expect(Fluxy.parameters['c'], 'd');
    },
  );

  test('copyWith with a new name matches the new pattern', () {
    final page = FluxyPage(name: '/user/:id', page: () => Container());
    final copy = page.copyWith(name: '/shop/:item');
    expect(copy.path.keys, ['item']);
    expect(copy.path.regex.hasMatch('/shop/42'), isTrue);
    expect(copy.path.regex.hasMatch('/user/42'), isFalse);
    expect(page.copyWith(title: 't').path.keys, ['id']);
  });

  test('matched pages carry the path key and the parameters', () {
    final tree = ParseRouteTree(routes: []);
    tree.addRoutes([
      FluxyPage(name: '/', page: () => Container()),
      FluxyPage(name: '/user/:id', page: () => Container()),
    ]);
    final decoded = tree.matchRoute('/user/7?tab=a');
    final last = decoded.currentTreeBranch.last;
    expect(last.key, const ValueKey('/user/7'));
    expect(last.name, '/user/7');
    expect(last.parameters, {'id': '7', 'tab': 'a'});
  });
}
