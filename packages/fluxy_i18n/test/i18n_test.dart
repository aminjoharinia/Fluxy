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
    Get.clearTranslations();
    Get.locale = null;
    Get.fallbackLocale = null;
    Get.addTranslations(AppTranslations().keys);
  });

  group('.tr lookup', () {
    test('no locale: the key itself', () {
      expect('hello'.tr, 'hello');
    });

    test('exact lang_country first', () {
      Get.locale = const Locale('en', 'GB');
      expect('hello'.tr, 'Hello mate');
    });

    test('then the same language in another country', () {
      Get.locale = const Locale('en', 'AU');
      // The last dictionary of that language wins (en_GB after en_US).
      expect('hello'.tr, 'Hello mate');
      expect('only_us'.tr, 'only_us');
    });

    test('then the fallback locale, lang_country then lang', () {
      Get.locale = const Locale('fa', 'IR');
      Get.fallbackLocale = const Locale('en', 'US');
      expect('hello'.tr, 'سلام');
      expect('only_us'.tr, 'US only');

      Get.fallbackLocale = const Locale('de');
      expect('only_de'.tr, 'nur de');
    });

    test('missing everywhere: the key itself', () {
      Get.locale = const Locale('en', 'US');
      Get.fallbackLocale = const Locale('de');
      expect('nope'.tr, 'nope');
    });
  });

  group('dictionaries', () {
    test('addTranslations replaces a whole dictionary', () {
      Get.locale = const Locale('en', 'US');
      Get.addTranslations({
        'en_US': {'bye': 'Bye'},
      });
      expect('bye'.tr, 'Bye');
      expect(Get.translations['en_US']!.containsKey('hello'), isFalse);
    });

    test('appendTranslations merges key by key, also into const maps', () {
      Get.locale = const Locale('en', 'US');
      Get.appendTranslations(const {
        'en_US': {'bye': 'Bye'},
        'it': {'ciao': 'Ciao'},
      });
      expect('bye'.tr, 'Bye');
      expect('hello'.tr, 'Hello');
      expect(Get.translations['it'], {'ciao': 'Ciao'});
    });

    test('clearTranslations empties every dictionary', () {
      Get.locale = const Locale('en', 'US');
      Get.clearTranslations();
      expect(Get.translations, isEmpty);
      expect('hello'.tr, 'hello');
    });

    test('notifyTranslationsChanged picks up direct edits', () {
      Get.locale = const Locale('en', 'US');
      expect('hello'.tr, 'Hello');
      Get.translations['en_US'] = {'hello': 'Hi'};
      Get.notifyTranslationsChanged();
      expect('hello'.tr, 'Hi');
    });

    test('every change bumps translationVersion', () {
      final start = Get.translationVersion.value;
      Get.locale = const Locale('de');
      Get.fallbackLocale = const Locale('en', 'US');
      Get.appendTranslations({
        'de': {'x': 'y'},
      });
      Get.notifyTranslationsChanged();
      expect(Get.translationVersion.value, start + 4);
    });
  });

  group('arguments', () {
    setUp(() {
      Get.locale = const Locale('en', 'US');
      Get.addTranslations({
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
    Get.locale = const Locale('en', 'US');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('hello'.tr)),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);

    Get.locale = const Locale('de');
    await tester.pump();
    expect(find.text('Hallo'), findsOneWidget);

    Get.appendTranslations({
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
