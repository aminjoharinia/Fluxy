import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_i18n/src/lookup.dart';
import 'package:fluxy_state/fluxy_state.dart';

List<String> _order(Map<String, Map<String, String>> dicts, Locale? locale,
    [Locale? fallback]) {
  final chain = buildChain(dicts, locale, fallback);
  return [
    for (final d in chain)
      d.key,
  ];
}

void main() {
  group('LocaleKey.parse', () {
    test('language, script and country, with _ or -', () {
      for (final (key, lang, script, country) in [
        ('en', 'en', null, null),
        ('en_US', 'en', null, 'US'),
        ('en-us', 'en', null, 'US'),
        ('zh_Hant', 'zh', 'Hant', null),
        ('zh-hant-tw', 'zh', 'Hant', 'TW'),
        ('es_419', 'es', null, '419'),
        ('persian_US', 'persian', null, 'US'),
        ('EN_us', 'en', null, 'US'),
      ]) {
        final k = LocaleKey.parse(key);
        expect((k.language, k.script, k.country), (lang, script, country),
            reason: key);
      }
    });

    test('a whole tag in Locale.languageCode reads as one', () {
      final k = LocaleKey.of(const Locale('en_US'));
      expect((k.language, k.country), ('en', 'US'));
    });
  });

  group('buildChain', () {
    final dicts = <String, Map<String, String>>{
      'en_GB': {},
      'en': {},
      'en_US': {},
      'zh_Hans': {},
      'zh_Hant': {},
      'zh_Hant_HK': {},
      'zh': {},
      'fa_IR': {},
      'fa': {},
    };

    test('exact, then the bare language, then siblings in the order added',
        () {
      expect(_order(dicts, const Locale('en', 'US')), ['en_US', 'en', 'en_GB']);
      expect(_order(dicts, const Locale('en', 'AU')), ['en', 'en_GB', 'en_US']);
      expect(_order(dicts, const Locale('en')), ['en', 'en_GB', 'en_US']);
    });

    test('script: lang_Script before lang_COUNTRY, same-script siblings first',
        () {
      const tw = Locale.fromSubtags(
          languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW');
      expect(_order(dicts, tw), ['zh_Hant', 'zh', 'zh_Hant_HK', 'zh_Hans']);
    });

    test('the fallback adds its exact and bare dictionaries, no siblings', () {
      expect(_order(dicts, const Locale('de'), const Locale('fa', 'AF')),
          ['fa']);
      expect(_order(dicts, const Locale('en', 'US'), const Locale('fa', 'IR')),
          ['en_US', 'en', 'en_GB', 'fa_IR', 'fa']);
    });

    test('no locale: only the fallback', () {
      expect(_order(dicts, null, const Locale('fa', 'IR')), ['fa_IR', 'fa']);
      expect(_order(dicts, null), isEmpty);
    });

    test('a dictionary appears once', () {
      expect(_order(dicts, const Locale('fa', 'IR'), const Locale('fa')),
          ['fa_IR', 'fa']);
    });
  });

  group('FluxyLocales', () {
    setUp(() => Fluxy.resetLocales());

    test('setting the same locale again changes nothing', () {
      Fluxy.locale = const Locale('en', 'US');
      final v = Fluxy.translationVersion.value;
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.fallbackLocale = null;
      expect(Fluxy.translationVersion.value, v);
    });

    test('addTranslations keeps the map object; append makes a new one', () {
      final en = <String, String>{'a': 'A'};
      Fluxy.addTranslations({'en_US': en});
      expect(identical(Fluxy.translations['en_US'], en), isTrue);
      Fluxy.appendTranslations({
        'en_US': {'b': 'B'},
      });
      expect(identical(Fluxy.translations['en_US'], en), isFalse);
      expect(en, {'a': 'A'}, reason: 'the given map is never written to');
    });

    test('a direct edit with a BCP 47 key is found after notify', () {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.translations['en-US'] = {'k': 'v'};
      Fluxy.notifyTranslationsChanged();
      expect('k'.tr, 'v');
    });

    test('resetLocales clears dictionaries and both locales', () {
      Fluxy.addTranslations({
        'en': {'a': 'A'},
      });
      Fluxy.locale = const Locale('en');
      Fluxy.fallbackLocale = const Locale('en');
      Fluxy.resetLocales();
      expect(Fluxy.translations, isEmpty);
      expect(Fluxy.locale, isNull);
      expect(Fluxy.fallbackLocale, isNull);
    });

    test('a Computed over Fluxy.locale follows it', () {
      final dir = Computed(() => Fluxy.locale?.languageCode ?? '-');
      expect(dir.value, '-');
      Fluxy.locale = const Locale('fa');
      expect(dir.value, 'fa');
      dir.dispose();
    });
  });
}
