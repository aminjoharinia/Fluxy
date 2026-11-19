import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => const {
    'en_US': {'hello': 'Hello', 'only_us': 'US only'},
    'en_GB': {'hello': 'Hello mate', 'colour': 'colour'},
    'fa_IR': {'hello': 'سلام'},
    'de': {'hello': 'Hallo', 'only_de': 'nur de'},
  };
}

void main() {
  setUp(() {
    Fluxy.clearTranslations();
    Fluxy.locale = null;
    Fluxy.fallbackLocale = null;
    Fluxy.addTranslations(AppTranslations().keys);
  });

  group('.tr lookup', () {
    test('no locale: the key itself', () {
      expect('hello'.tr, 'hello');
    });

    test('exact lang_country first', () {
      Fluxy.locale = const Locale('en', 'GB');
      expect('hello'.tr, 'Hello mate');
    });

    test('then every dictionary of the same language, in the order added',
        () {
      Fluxy.locale = const Locale('en', 'AU');
      // en_US was added before en_GB; both are searched (before v1.7 only
      // the last one added was, so en_US-only keys were missed).
      expect('hello'.tr, 'Hello');
      expect('only_us'.tr, 'US only');
      expect('colour'.tr, 'colour');
    });

    test('then the fallback locale, lang_country then lang', () {
      Fluxy.locale = const Locale('fa', 'IR');
      Fluxy.fallbackLocale = const Locale('en', 'US');
      expect('hello'.tr, 'سلام');
      expect('only_us'.tr, 'US only');

      Fluxy.fallbackLocale = const Locale('de');
      expect('only_de'.tr, 'nur de');
    });

    test('missing everywhere: the key itself', () {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.fallbackLocale = const Locale('de');
      expect('nope'.tr, 'nope');
    });
  });

  group('dictionaries', () {
    test('addTranslations replaces a whole dictionary', () {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.addTranslations({
        'en_US': {'bye': 'Bye'},
      });
      expect('bye'.tr, 'Bye');
      expect(Fluxy.translations['en_US']!.containsKey('hello'), isFalse);
    });

    test('appendTranslations merges key by key, also into const maps', () {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.appendTranslations(const {
        'en_US': {'bye': 'Bye'},
        'it': {'ciao': 'Ciao'},
      });
      expect('bye'.tr, 'Bye');
      expect('hello'.tr, 'Hello');
      expect(Fluxy.translations['it'], {'ciao': 'Ciao'});
    });

    test('clearTranslations empties every dictionary', () {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.clearTranslations();
      expect(Fluxy.translations, isEmpty);
      expect('hello'.tr, 'hello');
    });

    test('notifyTranslationsChanged picks up direct edits', () {
      Fluxy.locale = const Locale('en', 'US');
      expect('hello'.tr, 'Hello');
      Fluxy.translations['en_US'] = {'hello': 'Hi'};
      Fluxy.notifyTranslationsChanged();
      expect('hello'.tr, 'Hi');
    });

    test('every change bumps translationVersion', () {
      final start = Fluxy.translationVersion.value;
      Fluxy.locale = const Locale('de');
      Fluxy.fallbackLocale = const Locale('en', 'US');
      Fluxy.appendTranslations({
        'de': {'x': 'y'},
      });
      Fluxy.notifyTranslationsChanged();
      expect(Fluxy.translationVersion.value, start + 4);
    });
  });

  group('arguments', () {
    setUp(() {
      Fluxy.locale = const Locale('en', 'US');
      Fluxy.addTranslations({
        'en_US': {
          'greet': 'Hi %s and %s',
          'item': 'one item',
          'items': '%s items',
          'p': '@name is @admin, not @admin_email; @unknown stays',
          'one': 'one @n',
          'many': '@n many',
        },
      });
    });

    test('trArgs fills %s in order, extra placeholders stay', () {
      expect('greet'.trArgs(['A', 'B']), 'Hi A and B');
      expect('greet'.trArgs(['A']), 'Hi A and %s');
    });

    test('trPlural picks by count', () {
      expect('item'.trPlural('items', 1), 'one item');
      expect('item'.trPlural('items', 3, ['3']), '3 items');
    });

    test('trParams matches whole names, longest first, one pass', () {
      expect(
        'p'.trParams({'name': '@admin', 'admin': 'root', 'admin_email': 'x@y'}),
        '@admin is root, not x@y; @unknown stays',
      );
      expect('p'.trParams(), 'p'.tr);
    });

    test('trPluralParams picks by count', () {
      expect('one'.trPluralParams('many', 1, {'n': '1'}), 'one 1');
      expect('one'.trPluralParams('many', 2, {'n': '2'}), '2 many');
    });
  });

  testWidgets('an Obx showing .tr rebuilds on locale change', (tester) async {
    Fluxy.locale = const Locale('en', 'US');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('hello'.tr)),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);

    Fluxy.locale = const Locale('de');
    await tester.pump();
    expect(find.text('Hallo'), findsOneWidget);

    Fluxy.appendTranslations({
      'de': {'hello': 'Servus'},
    });
    await tester.pump();
    expect(find.text('Servus'), findsOneWidget);
  });

  test('rtlLanguages lists the right-to-left languages', () {
    expect(rtlLanguages, containsAll(['ar', 'fa', 'he']));
    expect(rtlLanguages, isNot(contains('en')));
  });
}
