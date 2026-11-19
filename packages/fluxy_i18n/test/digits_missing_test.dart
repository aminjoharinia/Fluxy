import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

void main() {
  setUp(() => Fluxy.resetLocales());

  group('localDigits', () {
    test('Persian (also persian_US), Pashto: Extended Arabic-Indic', () {
      for (final l in [
        const Locale('fa', 'IR'),
        const Locale('persian', 'US'),
        const Locale('ps'),
      ]) {
        expect('12:30 - 7'.localDigits(l), '۱۲:۳۰ - ۷', reason: '$l');
      }
    });

    test('Arabic: Arabic-Indic, Western in the Maghreb', () {
      expect('2026'.localDigits(const Locale('ar', 'EG')), '٢٠٢٦');
      expect('2026'.localDigits(const Locale('ar')), '٢٠٢٦');
      expect('2026'.localDigits(const Locale('ar', 'MA')), '2026');
    });

    test('Devanagari, Bengali; English, Urdu, Hindi unchanged', () {
      expect('305'.localDigits(const Locale('mr')), '३०५');
      expect('305'.localDigits(const Locale('bn')), '৩০৫');
      for (final l in ['en', 'ur', 'hi', 'de']) {
        expect('305'.localDigits(Locale(l)), '305', reason: l);
      }
    });

    test('defaults to Fluxy.locale; no locale: unchanged', () {
      expect('42'.localDigits(), '42');
      Fluxy.locale = const Locale('fa', 'IR');
      expect('42'.localDigits(), '۴۲');
      expect(1.5.localDigits(), '۱.۵');
      expect(7.localDigits(const Locale('en')), '7');
    });

    test('the same string comes back when nothing changes', () {
      const s = 'no digits';
      expect(identical(s.localDigits(const Locale('fa')), s), isTrue);
    });

    testWidgets('an Obx showing localDigits follows the language',
        (tester) async {
      Fluxy.locale = const Locale('en');
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('3'.localDigits())),
      ));
      expect(find.text('3'), findsOneWidget);
      Fluxy.locale = const Locale('fa');
      await tester.pump();
      expect(find.text('۳'), findsOneWidget);
    });
  });

  group('westernDigits', () {
    test('reads every native digit set back', () {
      expect('۱۲۳٤٥٦०৯๙０'.westernDigits, '1234560990');
      expect(int.parse('۱۴۰۵'.westernDigits), 1405);
      expect('abc 12'.westernDigits, 'abc 12');
    });
  });

  group('onMissingTranslation', () {
    test('called once per key until the locale or dictionaries change', () {
      final missed = <String>[];
      Fluxy.onMissingTranslation =
          (key, locale) => missed.add('$key@${locale?.languageCode}');
      Fluxy.addTranslations(const {
        'en_US': {'hi': 'Hi', 'n.other': '@count things'},
      });
      Fluxy.locale = const Locale('en', 'US');
      expect('hi'.tr, 'Hi');
      expect('nope'.tr, 'nope');
      expect('nope'.trParams({'a': 'b'}), 'nope');
      expect('n'.trCount(2), '2 things');
      expect('gone'.trCount(2), 'gone');
      expect(missed, ['nope@en', 'gone@en']);
      Fluxy.locale = const Locale('fa');
      'nope'.tr;
      expect(missed.last, 'nope@fa');
    });

    test('a key found in the fallback is not missing', () {
      final missed = <String>[];
      Fluxy.onMissingTranslation = (key, _) => missed.add(key);
      Fluxy.addTranslations(const {
        'persian_US': {'save': 'ذخیره'},
      });
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.fallbackLocale = const Locale('persian', 'US');
      'save'.tr;
      expect(missed, isEmpty);
    });

    test('resetLocales forgets the callback', () {
      Fluxy.onMissingTranslation = (_, _) {};
      Fluxy.resetLocales();
      expect(Fluxy.onMissingTranslation, isNull);
    });
  });
}
