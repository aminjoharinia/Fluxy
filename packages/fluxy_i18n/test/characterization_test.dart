// I18N-PLAN phase 0: what BOOFI, Hesabak and NestCut rely on, and the bugs
// B1-B12 (the ones that need no widgets live here; the rest are in
// fluxy_nav/test/internationalization/characterization_test.dart).
// A bug test is skipped until its phase fixes it.
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

const _persian = Locale('persian', 'US');
const _english = Locale('en', 'US');

/// Hesabak's shape: Persian text is the key; the English dictionary is a
/// `MapBase` that also answers lines built from a template (`'مانده: {0}'`).
class _TemplateDictionary extends MapBase<String, String> {
  final Map<String, String> _exact = const {'مانده': 'Balance'};

  @override
  String? operator [](Object? key) {
    if (key is! String) return null;
    final exact = _exact[key];
    if (exact != null) return exact;
    if (key.startsWith('مانده: ')) {
      return 'Balance: ${key.substring('مانده: '.length)}';
    }
    return null;
  }

  @override
  void operator []=(String key, String value) =>
      throw UnsupportedError('read-only');
  @override
  void clear() => throw UnsupportedError('read-only');
  @override
  Iterable<String> get keys => _exact.keys;
  @override
  String? remove(Object? key) => throw UnsupportedError('read-only');
}

void main() {
  setUp(() {
    Fluxy.clearTranslations();
    Fluxy.locale = null;
    Fluxy.fallbackLocale = null;
  });

  group('what the apps rely on', () {
    test('BOOFI / NestCut: persian_US and en_US, persian_US as fallback', () {
      Fluxy.addTranslations(const {
        'en_US': {'save': 'Save', 'only_en': 'English only'},
        'persian_US': {'save': 'ذخیره', 'only_fa': 'فقط فارسی'},
      });
      Fluxy.fallbackLocale = _persian;
      Fluxy.locale = _english;
      expect('save'.tr, 'Save');
      expect('only_fa'.tr, 'فقط فارسی'); // from the fallback
      Fluxy.locale = _persian;
      expect('save'.tr, 'ذخیره');
      expect('only_en'.tr, 'only_en'); // not in persian: the key
    });

    test('Hesabak: Persian text as the key comes back unchanged in Persian',
        () {
      Fluxy.addTranslations(const {
        'en_US': {'مانده': 'Balance'},
        'persian_US': {'legacy': 'قدیمی'},
      });
      Fluxy.fallbackLocale = _persian;
      Fluxy.locale = _persian;
      expect('مانده'.tr, 'مانده');
      expect('legacy'.tr, 'قدیمی');
      Fluxy.locale = _english;
      expect('مانده'.tr, 'Balance');
    });

    test('NestCut / BOOFI: @name placeholders, values inserted as given', () {
      Fluxy.addTranslations(const {
        'en_US': {'grace': '@days days left', 'until': 'Valid until @date'},
        'persian_US': {'grace': '@days روز مانده'},
      });
      Fluxy.locale = _persian;
      expect('grace'.trParams({'days': '۳'}), '۳ روز مانده');
      Fluxy.locale = _english;
      expect('until'.trParams({'date': '2026/11/19'}), 'Valid until 2026/11/19');
    });

    test('NestCut: dictionaries and locale set in main() before any app', () {
      Fluxy.addTranslations(const {
        'en_US': {'mm': 'mm'},
        'persian_US': {'mm': 'میلی‌متر'},
      });
      Fluxy.fallbackLocale = _persian;
      Fluxy.locale = _persian;
      expect('mm'.tr, 'میلی‌متر');
    });

    test('a key missing everywhere comes back as the key', () {
      Fluxy.addTranslations(const {
        'en_US': {'a': 'A'},
      });
      Fluxy.locale = _english;
      expect('not there'.tr, 'not there');
    });
  });

  group('bugs (skipped until fixed)', () {
    test('B1: a custom Map dictionary is kept, not copied', () {
      Fluxy.addTranslations({'en_US': _TemplateDictionary()});
      Fluxy.locale = _english;
      expect('مانده'.tr, 'Balance');
      expect('مانده: ۱۲۰'.tr, 'Balance: ۱۲۰');
    }, skip: 'I18N-PLAN phase 1');

    test('B2: no locale, a fallback locale: the fallback is used', () {
      Fluxy.addTranslations(const {
        'fa_IR': {'k': 'FA'},
      });
      Fluxy.fallbackLocale = const Locale('fa', 'IR');
      expect('k'.tr, 'FA');
    }, skip: 'I18N-PLAN phase 1');

    test('B4: the script code picks the dictionary', () {
      Fluxy.addTranslations(const {
        'zh_Hant': {'k': 'Traditional'},
        'zh_Hans': {'k': 'Simplified'},
      });
      Fluxy.locale = const Locale.fromSubtags(
          languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW');
      expect('k'.tr, 'Traditional');
    }, skip: 'I18N-PLAN phase 1');

    test('B5: a bare language wins over a sibling country, in any order', () {
      Fluxy.addTranslations(const {
        'pt': {'k': 'bare'},
      });
      Fluxy.addTranslations(const {
        'pt_PT': {'k': 'Portugal'},
      });
      Fluxy.locale = const Locale('pt', 'BR');
      expect('k'.tr, 'bare');
    }, skip: 'I18N-PLAN phase 1');

    test('B6: a BCP 47 key (en-US) is the same as en_US', () {
      Fluxy.addTranslations(const {
        'en-US': {'k': 'EN'},
      });
      Fluxy.locale = _english;
      expect('k'.tr, 'EN');
    }, skip: 'I18N-PLAN phase 1');

    test('B7: trArgs does not scan inserted values again', () {
      Fluxy.addTranslations(const {
        'en_US': {'k': '%s and %s'},
      });
      Fluxy.locale = _english;
      expect('k'.trArgs(['50%s', 'B']), '50%s and B');
    }, skip: 'I18N-PLAN phase 2');

    test('B8: trPlural without a plural key does not throw', () {
      Fluxy.addTranslations(const {
        'en_US': {'k': 'one item'},
      });
      Fluxy.locale = _english;
      expect('k'.trPlural(null, 2), 'one item');
      expect('k'.trPluralParams(null, 2), 'one item');
    }, skip: 'I18N-PLAN phase 2');

    testWidgets('B9: an Obx that reads Fluxy.locale rebuilds', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('${Fluxy.locale}')),
      ));
      Fluxy.locale = const Locale('de');
      await tester.pump();
      expect(find.text('de'), findsOneWidget);
    }, skip: true); // I18N-PLAN phase 1
  });
}
