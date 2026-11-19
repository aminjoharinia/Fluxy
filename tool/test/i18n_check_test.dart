import 'dart:io';

import 'package:test/test.dart';

import '../src/dart_tokens.dart';
import '../src/i18n_check_command.dart';

void main() {
  group('tokenize', () {
    test('strings: escapes, raw, triple, interpolation, comments', () {
      final t = tokenize(r'''
// 'not a string'
/* 'nor /* nested */ this' */
var a = 'it\'s' "xA\n" r'raw\n' """tri
ple""" 'v $name ${b.tr}';
''');
      final strings = t.where((x) => x.kind == TokenKind.string).toList();
      expect(strings.map((s) => s.value), [
        "it's",
        'xA\n',
        r'raw\n',
        'tri\nple',
        null,
      ]);
      expect(strings.last.interpolated, isTrue);
      // Code in the interpolation is tokenized.
      expect(t.any((x) => x.isIdent('tr')), isTrue);
      expect(t.any((x) => x.isIdent('name')), isTrue);
      expect(t.first.line, 3);
    });
  });

  group('analyze', () {
    I18nReport run(Map<String, String> files) => analyze(files);

    test('uses: literals before tr members, adjacent strings, plural keys',
        () {
      final r = run({
        'lib/a.dart': r'''
f(x) {
  'hello'.tr;
  'a' 'b'.trParams({'n': '1'});
  'items'.trCount(3);
  'item'.trPlural('items', 2);
  'v $x'.tr;
  x.tr;
  'not translated'.length;
}
''',
      });
      expect(r.uses.map((u) => u.key),
          ['hello', 'ab', 'items', 'item', 'items']);
      expect(r.uses.firstWhere((u) => u.key == 'items').plural, isTrue);
      expect(r.uses.first.line, 2);
      expect(r.dynamicUses, hasLength(2));
    });

    test('dictionaries: Translations getter, addTranslations, constants, '
        'constructor calls, spreads', () {
      final r = run({
        'lib/lang.dart': r'''
class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {'hello': 'Hello', 'only_en': 'x', ...common},
    'persian_US': kPersian,
    'fr': EnglishLike(kFrench),
  };
}
const common = <String, String>{'common': 'c'};
const Map<String, String> kPersian = {'hello': 'سلام'};
final kFrench = Map.of(const {'bonjour': 'b'});
class EnglishLike extends MapBase<String, String> {
  Iterable<String> get keys => _exact.keys;
}
''',
        'lib/main.dart': r'''
main() {
  Fluxy.addTranslations({'de': {'hallo': 'Hallo'}});
  FluxyApp(translationsKeys: const {'es': {'hola': 'h'}});
}
''',
      });
      expect(r.dictionaries.keys,
          unorderedEquals(['en_US', 'persian_US', 'fr', 'de', 'es']));
      expect(r.dictionaries['en_US'],
          unorderedEquals(['hello', 'only_en', 'common']));
      expect(r.dictionaries['persian_US'], ['hello']);
      expect(r.dictionaries['fr'], ['bonjour']);
      expect(r.dictionaries['de'], ['hallo']);
    });

    test('missing and unused, plural forms, ignore', () {
      final r = run({
        'lib/a.dart': r'''
class M extends Translations {
  get keys => {
    'en_US': {'hello': 'Hi', 'files.one': '1', 'files.other': 'n', 'old': 'o',
      'tpl {0}': 't'},
    'persian_US': {'hello': 'س'},
  };
}
f() { 'hello'.tr; 'files'.trCount(2); 'bye'.tr; 'bye'.tr; }
''',
      });
      final missing = r.missing();
      expect(missing['en_US']!.map((u) => u.key), ['bye', 'bye']);
      expect(missing['persian_US']!.map((u) => u.key),
          ['files', 'bye', 'bye']);
      expect(r.unused()['en_US'], ['old', 'tpl {0}']);
      expect(r.unused(ignore: RegExp(r'\{\d\}'))['en_US'], ['old']);
      expect(r.missing(ignore: RegExp('^bye\$'))['en_US'], isEmpty);
    });
  });

  group('runI18nCheck', () {
    late Directory project;
    setUp(() {
      project = Directory.systemTemp.createTempSync('i18n_check');
      File('${project.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(r'''
class M extends Translations {
  get keys => {'en_US': {'hello': 'Hi', 'old': 'o'}, 'fa_IR': {'hello': 'س'}};
}
f() { 'hello'.tr; 'bye'.tr; }
''');
    });
    tearDown(() => project.deleteSync(recursive: true));

    test('prints per locale; --fail exits 1 on a missing key', () async {
      final log = StringBuffer();
      expect(await runI18nCheck([project.path], log: log), 0);
      final text = log.toString();
      expect(text, contains('en_US: 2 keys, 1 missing, 1 unused'));
      expect(text, contains("'bye'  lib/a.dart:4"));
      expect(text, contains("'old'"));
      expect(await runI18nCheck([project.path, '--fail'], log: StringBuffer()),
          1);
    });

    test('--locale, --no-unused, bad options', () async {
      final log = StringBuffer();
      await runI18nCheck(
          [project.path, '--locale', 'fa_IR', '--no-unused'], log: log);
      expect(log.toString(), contains('fa_IR: 1 keys, 1 missing\n'));
      expect(log.toString(), isNot(contains('en_US:')));
      expect(await runI18nCheck(['--bogus'], log: StringBuffer()), 64);
      expect(await runI18nCheck([], log: StringBuffer()), 64);
    });
  });
}
