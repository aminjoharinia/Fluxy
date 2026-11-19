// I18N-PLAN phase 3: the app's direction rule, the locale handed to the
// Material / Cupertino app, the language switch without a hot reload, the
// supportedLocales warning.
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageScaffold;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:material_ui/material_ui.dart';

TextDirection? _direction;
Locale? _materialLocale;

Widget _probe() => Builder(builder: (context) {
      _direction = Directionality.of(context);
      _materialLocale = Localizations.localeOf(context);
      return const SizedBox();
    });

TextDirection _rtlFor(Locale l) => rtlLanguages.contains(l.languageCode)
    ? TextDirection.rtl
    : TextDirection.ltr;

class _Counted extends StatefulWidget {
  const _Counted();
  static int reassembles = 0, builds = 0;
  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void reassemble() {
    super.reassemble();
    _Counted.reassembles++;
  }

  @override
  Widget build(BuildContext context) {
    _Counted.builds++;
    return Text('hello'.tr);
  }
}

void main() {
  tearDown(() {
    Fluxy.reset();
    _direction = null;
    _materialLocale = null;
  });

  group('direction (D2)', () {
    testWidgets('no rule: left-to-right for Persian and Arabic',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('fa', 'IR'),
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
      expect(Fluxy.textDirection, TextDirection.ltr);
      Fluxy.locale = const Locale('ar');
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
    });

    testWidgets('directionFor follows the locale, without updateLocale',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('en', 'US'),
        directionFor: _rtlFor,
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
      Fluxy.locale = const Locale('fa', 'IR');
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.rtl);
      expect(Fluxy.textDirection, TextDirection.rtl);
    });

    testWidgets('textDirection wins over directionFor', (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('fa', 'IR'),
        textDirection: TextDirection.ltr,
        directionFor: _rtlFor,
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
    });

    testWidgets('a rebuilt app takes a new rule, or none', (tester) async {
      Widget app(TextDirection Function(Locale)? rule) => FluxyApp(
            locale: const Locale('fa', 'IR'),
            directionFor: rule,
            home: _probe(),
          );
      await tester.pumpWidget(app(_rtlFor));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.rtl);
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
    });

    testWidgets('an Obx reading Fluxy.textDirection follows the locale',
        (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('en', 'US'),
        directionFor: _rtlFor,
        home: Scaffold(body: Obx(() => Text('${Fluxy.textDirection}'))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('${TextDirection.ltr}'), findsOneWidget);
      Fluxy.locale = const Locale('he');
      await tester.pumpAndSettle();
      expect(find.text('${TextDirection.rtl}'), findsOneWidget);
    });

    testWidgets('FluxyCupertinoApp uses the same rule', (tester) async {
      await tester.pumpWidget(FluxyCupertinoApp(
        locale: const Locale('fa', 'IR'),
        home: CupertinoPageScaffold(child: _probe()),
      ));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.ltr);
      Fluxy.reset();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(FluxyCupertinoApp(
        locale: const Locale('fa', 'IR'),
        directionFor: _rtlFor,
        home: CupertinoPageScaffold(child: _probe()),
      ));
      await tester.pumpAndSettle();
      expect(_direction, TextDirection.rtl);
    });

    test('Fluxy.reset() forgets the rule', () {
      Fluxy.setTextDirectionRule(fixed: TextDirection.rtl);
      expect(Fluxy.textDirection, TextDirection.rtl);
      Fluxy.reset();
      expect(Fluxy.textDirection, TextDirection.ltr);
    });
  });

  group('the locale handed to MaterialApp', () {
    testWidgets('follows Fluxy.locale set directly', (tester) async {
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('en', 'US'),
        // The default localizations are English only.
        supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      expect(_materialLocale, const Locale('en', 'US'));
      Fluxy.locale = const Locale('en', 'GB');
      await tester.pumpAndSettle();
      expect(_materialLocale, const Locale('en', 'GB'));
    });

    testWidgets('a locale outside supportedLocales is logged once',
        (tester) async {
      final logs = <String>[];
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('tlh'),
        supportedLocales: const [Locale('en', 'US')],
        logWriterCallback: (text, {isError = false}) => logs.add(text),
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      Fluxy.appUpdate();
      await tester.pumpAndSettle();
      expect(logs.where((l) => l.contains('not in supportedLocales')),
          hasLength(1));
      expect(_materialLocale, const Locale('en', 'US'));
    });

    testWidgets('no warning when the app resolves locales itself',
        (tester) async {
      final logs = <String>[];
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('tlh', 'XX'),
        supportedLocales: const [Locale('en', 'US')],
        localeResolutionCallback: (_, supported) => supported.first,
        logWriterCallback: (text, {isError = false}) => logs.add(text),
        home: _probe(),
      ));
      await tester.pumpAndSettle();
      expect(logs.where((l) => l.contains('not in supportedLocales')),
          isEmpty);
    });
  });

  group('the language switch', () {
    testWidgets('updateLocale rebuilds plain widgets without reassemble',
        (tester) async {
      Fluxy.addTranslations(const {
        'en_US': {'hello': 'Hello'},
        'fa_IR': {'hello': 'سلام'},
      });
      _Counted.reassembles = 0;
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: _Counted()),
      ));
      await tester.pumpAndSettle();
      final builds = _Counted.builds;
      var done = false;
      Fluxy.updateLocale(const Locale('fa', 'IR')).then((_) => done = true);
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
      expect(_Counted.reassembles, 0);
      expect(_Counted.builds, greaterThan(builds));
      expect(done, isTrue);
    });

    testWidgets('a device-following app starts in the device language',
        (tester) async {
      tester.binding.platformDispatcher
        ..localeTestValue = const Locale('de', 'DE')
        ..localesTestValue = const [Locale('de', 'DE')];
      addTearDown(() => tester.binding.platformDispatcher
        ..clearLocaleTestValue()
        ..clearLocalesTestValue());
      await tester.pumpWidget(FluxyApp(home: _probe()));
      await tester.pumpAndSettle();
      expect(Fluxy.locale, const Locale('de', 'DE'));
    });

    testWidgets('FluxyApp(onMissingTranslation:) hears missing keys',
        (tester) async {
      final missed = <String>[];
      await tester.pumpWidget(FluxyApp(
        locale: const Locale('en', 'US'),
        translationsKeys: const {
          'en_US': {'hi': 'Hi'},
        },
        onMissingTranslation: (key, _) => missed.add(key),
        home: Scaffold(
          body: Builder(
            builder: (_) => Column(children: [Text('hi'.tr), Text('x'.tr)]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(missed, ['x']);
    });

    testWidgets('a locale set before runApp wins over the device',
        (tester) async {
      Fluxy.locale = const Locale('fa', 'IR');
      await tester.pumpWidget(FluxyApp(home: _probe()));
      await tester.pumpAndSettle();
      expect(Fluxy.locale, const Locale('fa', 'IR'));
    });
  });
}
