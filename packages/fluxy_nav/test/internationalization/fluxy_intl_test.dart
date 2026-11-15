import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

const _en = {'hello': 'Hello', 'only_en': 'only en'};
const _fa = {'hello': 'سلام'};

void _load() {
  Get.clearTranslations();
  Get.addTranslations(const {'en_US': _en, 'persian_US': _fa});
  Get.fallbackLocale = const Locale('persian', 'US');
  Get.locale = const Locale('en', 'US');
}

void main() {
  setUp(_load);
  tearDown(() {
    Get.clearTranslations();
    Get.locale = null;
    Get.fallbackLocale = null;
  });

  group('lookup', () {
    test('full locale, then same language, then fallback, then the key', () {
      Get.addTranslations(const {
        'en_GB': {'colour': 'colour'},
        'de': {'only_de': 'nur de'},
      });
      Get.fallbackLocale = const Locale('de');
      Get.locale = const Locale('en', 'US');
      expect('hello'.tr, 'Hello'); // en_US
      Get.locale = const Locale('en', 'AU');
      expect('colour'.tr, 'colour'); // same language (en_GB, the last en_*)
      expect('only_de'.tr, 'nur de'); // fallback language
      expect('missing'.tr, 'missing'); // the key
    });

    test('a locale change or new dictionary is seen at once', () {
      expect('hello'.tr, 'Hello');
      Get.locale = const Locale('persian', 'US');
      expect('hello'.tr, 'سلام');
      expect('only_en'.tr, 'only_en'); // fallback is persian: not found
      Get.appendTranslations(const {
        'persian_US': {'only_en': 'فقط'},
      });
      expect('only_en'.tr, 'فقط');
    });

    test('no locale returns the key', () {
      Get.locale = null;
      expect('hello'.tr, 'hello');
    });
  });

  group('appendTranslations', () {
    test('works on dictionaries that were added as const maps', () {
      expect(
          () => Get.appendTranslations(const {
                'en_US': {'new': 'New'},
              }),
          returnsNormally);
      expect('new'.tr, 'New');
      expect('hello'.tr, 'Hello');
      expect(_en.containsKey('new'), isFalse, reason: 'source map untouched');
    });
  });

  group('trParams', () {
    test('a name only matches a whole placeholder', () {
      Get.appendTranslations(const {
        'en_US': {'mail': '@admin <@admin_email>'},
      });
      expect(
          'mail'.trParams({'admin': 'Ann', 'admin_email': 'ann@x.io'}),
          'Ann <ann@x.io>');
      expect('mail'.trParams({'admin': 'Ann'}), 'Ann <@admin_email>');
    });

    test('inserted values are not replaced again', () {
      Get.appendTranslations(const {
        'en_US': {'pair': '@a and @b'},
      });
      expect('pair'.trParams({'a': '@b', 'b': 'B'}), '@b and B');
    });

    test('hyphenated names, non-ASCII neighbours, stray @', () {
      Get.appendTranslations(const {
        'en_US': {
          'h': 'Hi @user-name!',
          'fa': '@nروز پیش',
          'at': 'mail @ home, @n',
        },
      });
      expect('h'.trParams({'user-name': 'Bo'}), 'Hi Bo!');
      expect('fa'.trParams({'n': '3'}), '3روز پیش');
      expect('at'.trParams({'n': '2'}), 'mail @ home, 2');
    });

    test('trArgs replaces %s in order', () {
      Get.appendTranslations(const {
        'en_US': {'args': '%s of %s'},
      });
      expect('args'.trArgs(['1', '2']), '1 of 2');
    });
  });

  group('reactive .tr', () {
    testWidgets('an Obx that only reads .tr rebuilds on a locale change',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => Text('hello'.tr)),
      ));
      expect(find.text('Hello'), findsOneWidget);
      Get.locale = const Locale('persian', 'US');
      await tester.pump();
      await tester.pump();
      expect(find.text('سلام'), findsOneWidget);
    });

    testWidgets('updateLocale(rebuildAll: false) updates Obx text',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(
        locale: const Locale('en', 'US'),
        home: Scaffold(body: Obx(() => Text('hello'.tr))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      Get.updateLocale(const Locale('persian', 'US'), rebuildAll: false);
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
      Get.reset();
    });

    testWidgets('updateLocale() still rebuilds plain widgets', (tester) async {
      await tester.pumpWidget(GetMaterialApp(
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: _PlainTr()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      Get.updateLocale(const Locale('persian', 'US'));
      await tester.pumpAndSettle();
      expect(find.text('سلام'), findsOneWidget);
      Get.reset();
    });
  });
}

class _PlainTr extends StatelessWidget {
  const _PlainTr();
  @override
  Widget build(BuildContext context) => Text('hello'.tr);
}
