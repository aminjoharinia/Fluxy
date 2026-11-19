import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

const _z = PluralCategory.zero,
    _one = PluralCategory.one,
    _two = PluralCategory.two,
    _f = PluralCategory.few,
    _m = PluralCategory.many,
    _o = PluralCategory.other;

void _expectRule(String lang, Map<num, PluralCategory> cases) {
  cases.forEach((n, c) => expect(pluralCategory(lang, n), c,
      reason: '$lang $n'));
}

void main() {
  group('pluralCategory (CLDR)', () {
    test('English and the default', () {
      _expectRule('en', {0: _o, 1: _one, 2: _o, 1.5: _o, 1.0: _one, -1: _one});
      _expectRule('xx', {1: _one, 2: _o}); // unknown: English rule
      _expectRule('en_US', {1: _one});
    });

    test('Persian: 0 and 1 are one (also persian_US / farsi)', () {
      for (final l in ['fa', 'fa_IR', 'persian_US', 'farsi']) {
        _expectRule(l, {0: _one, 1: _one, 2: _o, 0.5: _one, 1.5: _o});
      }
    });

    test('French and Portuguese', () {
      _expectRule('fr', {0: _one, 1: _one, 1.5: _one, 2: _o});
      _expectRule('pt', {0: _one, 1: _one, 2: _o});
      _expectRule('pt_PT', {0: _o, 1: _one, 2: _o});
    });

    test('Russian', () {
      _expectRule('ru', {
        1: _one, 21: _one, 101: _one, 11: _m, 2: _f, 4: _f, 22: _f, 12: _m,
        14: _m, 5: _m, 0: _m, 111: _m, 1.5: _o,
      });
    });

    test('Polish and Czech', () {
      _expectRule('pl', {1: _one, 2: _f, 22: _f, 12: _m, 5: _m, 21: _m, 0: _m});
      _expectRule('cs', {1: _one, 2: _f, 4: _f, 5: _o, 0: _o, 1.5: _m});
    });

    test('Arabic: all six', () {
      _expectRule('ar', {
        0: _z, 1: _one, 2: _two, 3: _f, 10: _f, 103: _f, 11: _m, 99: _m,
        100: _o, 102: _o,
      });
    });

    test('Hebrew, Romanian, Chinese', () {
      _expectRule('he', {1: _one, 2: _two, 3: _o, 0.5: _one});
      _expectRule('ro', {1: _one, 0: _f, 2: _f, 19: _f, 20: _o, 101: _f});
      _expectRule('zh', {0: _o, 1: _o, 2: _o});
    });
  });

  group('trCount', () {
    setUp(() {
      Fluxy.resetLocales();
      Fluxy.addTranslations(const {
        'en_US': {
          'items': 'items',
          'items.one': '@count item',
          'items.other': '@count items',
          'items.zero': 'No items',
          'files.other': '@count files in @dir',
          'base': 'just @count',
        },
        'ru_RU': {
          'items.one': '@count файл',
          'items.few': '@count файла',
          'items.many': '@count файлов',
          'items.other': '@count файла',
        },
        'ar': {
          'items.zero': 'لا ملفات',
          'items.two': 'ملفان',
          'items.other': '@count ملفات',
        },
        'persian_US': {
          'items.other': '@count فایل',
        },
      });
    });

    test('English one / other, an explicit zero', () {
      Fluxy.locale = const Locale('en', 'US');
      expect('items'.trCount(1), '1 item');
      expect('items'.trCount(3), '3 items');
      expect('items'.trCount(0), 'No items');
      expect('items'.trCount(1.5), '1.5 items');
    });

    test('Russian picks one / few / many', () {
      Fluxy.locale = const Locale('ru', 'RU');
      expect('items'.trCount(1), '1 файл');
      expect('items'.trCount(3), '3 файла');
      expect('items'.trCount(5), '5 файлов');
      expect('items'.trCount(21), '21 файл');
    });

    test('a missing form falls back to other', () {
      Fluxy.locale = const Locale('ar');
      expect('items'.trCount(0), 'لا ملفات');
      expect('items'.trCount(2), 'ملفان');
      expect('items'.trCount(5), '5 ملفات');
      Fluxy.locale = const Locale('persian', 'US');
      expect('items'.trCount(1), '1 فایل');
    });

    test('the rules follow the dictionary that answers (the fallback)', () {
      Fluxy.locale = const Locale('de');
      Fluxy.fallbackLocale = const Locale('ru', 'RU');
      expect('items'.trCount(5), '5 файлов');
    });

    test('params, and no forms at all: the key itself', () {
      Fluxy.locale = const Locale('en', 'US');
      expect('files'.trCount(2, {'dir': '/tmp'}), '2 files in /tmp');
      expect('base'.trCount(4), 'just 4');
      expect('nothing'.trCount(4), 'nothing');
    });

    testWidgets('an Obx with trCount follows the locale', (tester) async {
      Fluxy.locale = const Locale('en', 'US');
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('items'.trCount(5))),
      ));
      expect(find.text('5 items'), findsOneWidget);
      Fluxy.locale = const Locale('ru', 'RU');
      await tester.pump();
      expect(find.text('5 файлов'), findsOneWidget);
    });
  });

  group('trPlural / trPluralParams (two keys)', () {
    setUp(() {
      Fluxy.resetLocales();
      Fluxy.addTranslations(const {
        'en_US': {'item': '%s item', 'items': '%s items'},
        'fr_FR': {'item': '@n élément', 'items': '@n éléments'},
      });
    });

    test('one category: the key; otherwise the plural key', () {
      Fluxy.locale = const Locale('en', 'US');
      expect('item'.trPlural('items', 1, ['1']), '1 item');
      expect('item'.trPlural('items', 0, ['0']), '0 items');
      Fluxy.locale = const Locale('fr', 'FR');
      expect('item'.trPluralParams('items', 0, {'n': '0'}), '0 élément');
      expect('item'.trPluralParams('items', 2, {'n': '2'}), '2 éléments');
    });

    test('no count: the plural key', () {
      Fluxy.locale = const Locale('en', 'US');
      expect('item'.trPlural('items', null, ['x']), 'x items');
    });
  });

  group('trArgs', () {
    test('one pass: values are not scanned, leftovers stay', () {
      Fluxy.resetLocales();
      Fluxy.addTranslations(const {
        'en': {'k': '%s / %s / %s'},
      });
      Fluxy.locale = const Locale('en');
      expect('k'.trArgs(['%s', 'b']), '%s / b / %s');
      expect('k'.trArgs(['a', 'b', 'c', 'd']), 'a / b / c');
      expect('k'.trArgs(), '%s / %s / %s');
    });
  });
}
