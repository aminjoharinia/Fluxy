// The language switch and app wiring the apps rely on,
// and the bugs that need an app (B3, B10, B12, D2), fixed in phases 1 and 3.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:material_ui/material_ui.dart';

const _persian = Locale('persian', 'US');
const _english = Locale('en', 'US');

class _Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => const {
        'en_US': {'hello': 'Hello', 'page': 'Second page'},
        'persian_US': {'hello': 'سلام', 'page': 'صفحه دوم'},
        'fa_IR': {'hello': 'سلام'},
      };
}

class _PlainTr extends StatelessWidget {
  const _PlainTr(this.keyName);
  final String keyName;
  @override
  Widget build(BuildContext context) => Text(keyName.tr);
}

TextDirection? _rootDirection;

Widget _directionProbe() => Builder(builder: (context) {
      _rootDirection = Directionality.of(context);
      return const SizedBox();
    });

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
      ..clearLocaleTestValue()
      ..clearLocalesTestValue();
    Fluxy.reset();
    Fluxy.locale = null;
    Fluxy.fallbackLocale = null;
    _rootDirection = null;
  });

  group('what the apps rely on', () {
    testWidgets('updateLocale reaches Obx, plain and const widgets',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: _english,
        fallbackLocale: _persian,
        home: Scaffold(
          body: Column(children: [
            Obx(() => Text('obx:${'hello'.tr}')),
            Builder(builder: (_) => Text('plain:${'hello'.tr}')),
            const _PlainTr('page'),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('obx:Hello'), findsOneWidget);
      expect(find.text('plain:Hello'), findsOneWidget);
      expect(find.text('Second page'), findsOneWidget);

      Fluxy.updateLocale(_persian);
      await tester.pumpAndSettle();
      expect(find.text('obx:سلام'), findsOneWidget);
      expect(find.text('plain:سلام'), findsOneWidget);
      expect(find.text('صفحه دوم'), findsOneWidget);
    });

    testWidgets('updateLocale reaches a page under the top one',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: _english,
        home: const Scaffold(body: _PlainTr('hello')),
      ));
      await tester.pumpAndSettle();
      Fluxy.to(() => const Scaffold(body: _PlainTr('page')));
      await tester.pumpAndSettle();
      Fluxy.updateLocale(_persian);
      await tester.pumpAndSettle();
      expect(find.text('صفحه دوم'), findsOneWidget);
      Fluxy.back();
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
    });

    testWidgets('the whole app in an Obx, passing a new locale',
        (tester) async {
      final persian = false.obs;
      await tester.pumpWidget(Obx(() => FluxyApp(
            translations: _Messages(),
            locale: persian.value ? _persian : _english,
            fallbackLocale: _persian,
            home: const Scaffold(body: _PlainTr('hello')),
          )));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      persian.value = true;
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
    });

    testWidgets('translations and locale set before runApp',
        (tester) async {
      Fluxy.addTranslations(_Messages().keys);
      Fluxy.fallbackLocale = _persian;
      Fluxy.locale = _persian;
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: _persian,
        fallbackLocale: _persian,
        home: const Scaffold(body: _PlainTr('hello')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
    });

    testWidgets('the persian_US locale leaves the root left-to-right',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: _persian,
        home: _directionProbe(),
      ));
      await tester.pumpAndSettle();
      expect(_rootDirection, TextDirection.ltr);
    });

    testWidgets('textDirection: given by the app wins', (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: _english,
        textDirection: TextDirection.rtl,
        home: _directionProbe(),
      ));
      await tester.pumpAndSettle();
      expect(_rootDirection, TextDirection.rtl);
    });
  });

  group('bugs and decisions', () {
    testWidgets('B3: an app without a locale starts in the device language',
        (tester) async {
      tester.binding.platformDispatcher
        ..localeTestValue = const Locale('en', 'US')
        ..localesTestValue = const [Locale('en', 'US')];
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        home: const Scaffold(body: _PlainTr('hello')),
      ));
      await tester.pumpAndSettle();
      expect(Fluxy.locale, const Locale('en', 'US'));
      expect(find.text('Hello'), findsOneWidget);
    });

    test('B10: Fluxy.reset() forgets the locale and the fallback', () {
      Fluxy.locale = const Locale('de');
      Fluxy.fallbackLocale = _english;
      Fluxy.reset();
      expect(Fluxy.locale, isNull);
      expect(Fluxy.fallbackLocale, isNull);
    });

    testWidgets('updateLocale completes once the frame is pumped',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: _english,
        home: const Scaffold(body: _PlainTr('hello')),
      ));
      await tester.pumpAndSettle();
      var done = false;
      Fluxy.updateLocale(_persian).then((_) => done = true);
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(find.text('سلام'), findsOneWidget);
    });

    testWidgets('D2 / B12: a Persian locale (fa_IR) leaves the root '
        'left-to-right', (tester) async {
      await tester.pumpWidget(FluxyApp(
        translations: _Messages(),
        locale: const Locale('fa', 'IR'),
        home: _directionProbe(),
      ));
      await tester.pumpAndSettle();
      expect(_rootDirection, TextDirection.ltr);
    });
  });
}
