/// `tool/i18n_check.dart`: compares the keys an app translates (`'key'.tr`,
/// `trParams`, `trArgs`, `trCount`, `trPlural`…) with its dictionaries.
library;

import 'dart:io';

import 'dart_tokens.dart';
import 'migrate_command.dart' show dartFiles;

const _trMembers = {
  'tr',
  'trParams',
  'trArgs',
  'trCount',
  'trPlural',
  'trPluralParams',
};
const _pluralForms = ['zero', 'one', 'two', 'few', 'many', 'other'];

/// A key used in code.
class KeyUse {
  KeyUse(this.key, this.file, this.line, {this.plural = false});
  final String key;
  final String file;
  final int line;

  /// From `trCount`: the forms are `key.one`, `key.other`…
  final bool plural;
}

/// What a project translates and what its dictionaries hold.
class I18nReport {
  final uses = <KeyUse>[];

  /// `.tr` on something that is not a plain string literal (an
  /// interpolation, a variable): not checked.
  final dynamicUses = <KeyUse>[];

  /// Locale key ("en_US") -> dictionary keys.
  final dictionaries = <String, Set<String>>{};

  /// Locale -> keys used in code and found in no form in its dictionary.
  Map<String, List<KeyUse>> missing({RegExp? ignore}) => {
        for (final MapEntry(key: locale, value: keys) in dictionaries.entries)
          locale: [
            for (final use in uses)
              if (!(ignore?.hasMatch(use.key) ?? false) && !_has(keys, use))
                use,
          ],
      };

  /// Locale -> dictionary keys no code uses.
  Map<String, List<String>> unused({RegExp? ignore}) {
    final used = <String>{};
    for (final use in uses) {
      used.add(use.key);
      if (use.plural) {
        for (final form in _pluralForms) {
          used.add('${use.key}.$form');
        }
      }
    }
    return {
      for (final MapEntry(key: locale, value: keys) in dictionaries.entries)
        locale: [
          for (final key in keys)
            if (!used.contains(key) && !(ignore?.hasMatch(key) ?? false)) key,
        ],
    };
  }

  static bool _has(Set<String> keys, KeyUse use) =>
      keys.contains(use.key) ||
      (use.plural && _pluralForms.any((f) => keys.contains('${use.key}.$f')));
}

/// Scans [files] (path -> source).
I18nReport analyze(Map<String, String> files) {
  final report = I18nReport();
  final tokensByFile = {
    for (final MapEntry(:key, :value) in files.entries) key: tokenize(value),
  };
  final symbols = _Symbols(tokensByFile.values);
  for (final MapEntry(key: file, value: tokens) in tokensByFile.entries) {
    _collectUses(file, tokens, report);
    _collectDictionaries(tokens, symbols, report);
  }
  return report;
}

/// Adjacent string literals from [start]: (value or null if any is
/// interpolated, index after the run). Null when [start] isn't a string.
(String?, int)? _stringRun(List<Token> t, int start) {
  if (start >= t.length || t[start].kind != TokenKind.string) return null;
  final value = StringBuffer();
  var dynamic = false;
  var i = start;
  while (i < t.length && t[i].kind == TokenKind.string) {
    final v = t[i].value;
    if (v == null) {
      dynamic = true;
    } else {
      value.write(v);
    }
    i++;
  }
  return (dynamic ? null : value.toString(), i);
}

void _collectUses(String file, List<Token> t, I18nReport report) {
  for (var i = 0; i + 2 < t.length; i++) {
    final member = t[i + 2];
    if (!t[i + 1].isPunct('.') ||
        !member.isIdent() ||
        !_trMembers.contains(member.text)) {
      continue;
    }
    // Find the start of the receiver: a run of strings ending at i.
    if (t[i].kind == TokenKind.string) {
      var s = i;
      while (s > 0 && t[s - 1].kind == TokenKind.string) {
        s--;
      }
      final (value, _) = _stringRun(t, s)!;
      final plural = member.text == 'trCount';
      final use = KeyUse(value ?? t[i].text, file, t[s].line, plural: plural);
      (value == null ? report.dynamicUses : report.uses).add(use);
      // trPlural('pluralKey', …): that key is used too.
      if ((member.text == 'trPlural' || member.text == 'trPluralParams') &&
          i + 4 < t.length &&
          t[i + 3].isPunct('(')) {
        final run = _stringRun(t, i + 4);
        if (run != null) {
          final (pv, _) = run;
          final u = KeyUse(pv ?? t[i + 4].text, file, t[i + 4].line);
          (pv == null ? report.dynamicUses : report.uses).add(u);
        }
      }
    } else if (t[i].isIdent() || t[i].isPunct(')') || t[i].isPunct(']')) {
      report.dynamicUses.add(KeyUse(t[i].text, file, t[i].line));
    }
  }
}

/// Top-level and class-level `name = expression` declarations.
class _Symbols {
  _Symbols(Iterable<List<Token>> files) {
    for (final t in files) {
      var depth = 0;
      for (var i = 0; i + 1 < t.length; i++) {
        final tok = t[i];
        if (tok.isPunct('{')) depth++;
        if (tok.isPunct('}')) depth--;
        if (depth <= 1 && tok.isIdent() && t[i + 1].isPunct('=')) {
          _defs.putIfAbsent(tok.text, () => (t, i + 2));
        }
      }
    }
  }

  final _defs = <String, (List<Token>, int)>{};

  (List<Token>, int)? operator [](String name) => _defs[name];
}

void _collectDictionaries(
    List<Token> t, _Symbols symbols, I18nReport report) {
  void addLocales(List<Token> tokens, int at) {
    final locales = _evalLocales(tokens, at, symbols, 0);
    locales?.forEach((locale, keys) {
      report.dictionaries.putIfAbsent(locale, () => <String>{}).addAll(keys);
    });
  }

  for (var i = 0; i + 2 < t.length; i++) {
    // get keys => { ... }   /   get keys { return { ... }; }
    if (t[i].isIdent('get') && t[i + 1].isIdent('keys')) {
      if (t[i + 2].isPunct('=>')) {
        addLocales(t, i + 3);
      } else if (t[i + 2].isPunct('{')) {
        for (var j = i + 3; j < t.length && !t[j].isPunct('}'); j++) {
          if (t[j].isIdent('return')) {
            addLocales(t, j + 1);
            break;
          }
        }
      }
    }
    // addTranslations({...}) / appendTranslations({...})
    if ((t[i].isIdent('addTranslations') ||
            t[i].isIdent('appendTranslations')) &&
        t[i + 1].isPunct('(')) {
      addLocales(t, i + 2);
    }
    // FluxyApp(translationsKeys: {...})
    if (t[i].isIdent('translationsKeys') && t[i + 1].isPunct(':')) {
      addLocales(t, i + 2);
    }
  }
}

/// Skips `const`, `new` and type arguments before an expression.
int _skipPrefix(List<Token> t, int i) {
  while (i < t.length) {
    if (t[i].isIdent('const') || t[i].isIdent('new')) {
      i++;
    } else if (t[i].isPunct('<')) {
      var depth = 0;
      while (i < t.length) {
        if (t[i].isPunct('<')) depth++;
        if (t[i].isPunct('>')) depth--;
        i++;
        if (depth == 0) break;
      }
    } else {
      break;
    }
  }
  return i;
}

/// The end of the expression starting at [i] (a `,`, `)`, `}` or `;` at
/// depth 0).
int _skipExpression(List<Token> t, int i) {
  var depth = 0;
  while (i < t.length) {
    final tok = t[i];
    if (tok.isPunct('(') || tok.isPunct('[') || tok.isPunct('{')) depth++;
    if (tok.isPunct(')') || tok.isPunct(']') || tok.isPunct('}')) {
      if (depth == 0) return i;
      depth--;
    }
    if (depth == 0 && (tok.isPunct(',') || tok.isPunct(';'))) return i;
    i++;
  }
  return i;
}

/// A map literal at [i]: calls [entry] with (key or null, value index) and
/// [spread] with the index of a spread's expression.
void _mapEntries(
  List<Token> t,
  int i,
  void Function(String? key, int valueAt) entry,
  void Function(int spreadAt) spread,
) {
  var j = i + 1; // after {
  while (j < t.length && !t[j].isPunct('}')) {
    if (t[j].isPunct('...') || t[j].isPunct('...?')) {
      spread(j + 1);
      j = _skipExpression(t, j + 1);
    } else {
      final run = _stringRun(t, j);
      String? key;
      var k = j;
      if (run != null) {
        key = run.$1;
        k = run.$2;
      } else {
        k = _skipExpression(t, j);
        // Not a string key: find the ':' anyway.
      }
      if (k < t.length && t[k].isPunct(':')) {
        entry(key, k + 1);
        j = _skipExpression(t, k + 1);
      } else {
        j = _skipExpression(t, k);
      }
    }
    if (j < t.length && t[j].isPunct(',')) j++;
  }
}

Map<String, Set<String>>? _evalLocales(
    List<Token> t, int i, _Symbols symbols, int depth) {
  if (depth > 8) return null;
  i = _skipPrefix(t, i);
  if (i >= t.length) return null;
  if (t[i].isPunct('{')) {
    final result = <String, Set<String>>{};
    _mapEntries(t, i, (locale, valueAt) {
      if (locale == null) return;
      final keys = _evalDictionary(t, valueAt, symbols, 0);
      if (keys != null) {
        result.putIfAbsent(locale, () => <String>{}).addAll(keys);
      }
    }, (spreadAt) {
      _evalLocales(t, spreadAt, symbols, depth + 1)?.forEach((l, k) {
        result.putIfAbsent(l, () => <String>{}).addAll(k);
      });
    });
    return result;
  }
  if (t[i].isIdent()) {
    final def = symbols[t[i].text];
    if (def != null && i + 1 < t.length && !t[i + 1].isPunct('(')) {
      return _evalLocales(def.$1, def.$2, symbols, depth + 1);
    }
  }
  return null;
}

Set<String>? _evalDictionary(
    List<Token> t, int i, _Symbols symbols, int depth) {
  if (depth > 8) return null;
  i = _skipPrefix(t, i);
  if (i >= t.length) return null;
  if (t[i].isPunct('{')) {
    final keys = <String>{};
    _mapEntries(t, i, (key, _) {
      if (key != null) keys.add(key);
    }, (spreadAt) {
      keys.addAll(_evalDictionary(t, spreadAt, symbols, depth + 1) ?? {});
    });
    return keys;
  }
  if (t[i].isIdent()) {
    // Name(arg, …) or Name.ctor(arg, …): the first argument
    // (`EnglishTranslations(kDictionary)`, `Map.of(x)`).
    var j = i + 1;
    while (j + 1 < t.length && t[j].isPunct('.') && t[j + 1].isIdent()) {
      j += 2;
    }
    if (j < t.length && t[j].isPunct('<')) j = _skipPrefix(t, j);
    if (j < t.length && t[j].isPunct('(')) {
      return _evalDictionary(t, j + 1, symbols, depth + 1);
    }
    if (j == i + 1) {
      final def = symbols[t[i].text];
      if (def != null) return _evalDictionary(def.$1, def.$2, symbols, depth + 1);
    }
  }
  return null;
}

/// Runs the check from the command line; returns the exit code.
Future<int> runI18nCheck(List<String> args, {StringSink? log}) async {
  final out = log ?? stdout;
  String? project;
  final locales = <String>[];
  RegExp? ignore;
  var showUnused = true;
  var fail = false;
  final dirs = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() {
      if (i + 1 >= args.length) throw FormatException('$a needs a value');
      return args[++i];
    }

    try {
      switch (a) {
        case '--help' || '-h':
          out.writeln(_usage);
          return 0;
        case '--locale':
          locales.add(next());
        case '--ignore':
          ignore = RegExp(next());
        case '--dir':
          dirs.add(next());
        case '--no-unused':
          showUnused = false;
        case '--fail':
          fail = true;
        default:
          if (a.startsWith('-')) throw FormatException('unknown option $a');
          if (project != null) throw const FormatException('one project only');
          project = a;
      }
    } on FormatException catch (e) {
      out.writeln('${e.message}\n\n$_usage');
      return 64;
    }
  }
  if (project == null) {
    out.writeln(_usage);
    return 64;
  }
  final files = <String, String>{};
  for (final dir in dirs.isEmpty ? ['lib'] : dirs) {
    final root = Directory('$project/$dir');
    if (!root.existsSync()) continue;
    for (final f in dartFiles(root)) {
      final rel = f.path.startsWith('$project/')
          ? f.path.substring(project.length + 1)
          : f.path;
      files[rel] = f.readAsStringSync();
    }
  }
  final report = analyze(files);
  if (report.dictionaries.isEmpty) {
    out.writeln('No dictionaries found (a Translations `keys` getter, '
        'addTranslations / appendTranslations, or translationsKeys:).');
    return fail ? 1 : 0;
  }
  final missing = report.missing(ignore: ignore);
  final unused = report.unused(ignore: ignore);
  final distinctUsed = {for (final u in report.uses) u.key}.length;
  out.writeln('${report.uses.length} uses of $distinctUsed keys in '
      '${files.length} files; ${report.dynamicUses.length} not checked '
      '(an interpolation or a variable).');
  var anyMissing = false;
  for (final locale in report.dictionaries.keys) {
    if (locales.isNotEmpty && !locales.contains(locale)) continue;
    final miss = missing[locale]!;
    final byKey = <String, List<KeyUse>>{};
    for (final u in miss) {
      byKey.putIfAbsent(u.key, () => []).add(u);
    }
    final unusedKeys = unused[locale]!;
    anyMissing |= byKey.isNotEmpty;
    out.writeln('\n$locale: ${report.dictionaries[locale]!.length} keys, '
        '${byKey.length} missing'
        '${showUnused ? ', ${unusedKeys.length} unused' : ''}');
    if (byKey.isNotEmpty) {
      out.writeln('  Missing:');
      byKey.forEach((key, at) {
        final where = at.take(3).map((u) => '${u.file}:${u.line}').join(', ');
        final more = at.length > 3 ? ' (+${at.length - 3})' : '';
        out.writeln('    ${_quote(key)}  $where$more');
      });
    }
    if (showUnused && unusedKeys.isNotEmpty) {
      out.writeln('  Unused:');
      for (final key in unusedKeys) {
        out.writeln('    ${_quote(key)}');
      }
    }
  }
  return fail && anyMissing ? 1 : 0;
}

String _quote(String s) =>
    "'${s.replaceAll('\\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";

const _usage = '''
Lists translation keys used in code but missing from a dictionary, and
dictionary keys no code uses.

  dart run tool/i18n_check.dart <project-dir> [options]

Options:
  --locale <key>    Only this dictionary (repeatable), e.g. en_US.
  --ignore <regex>  Leave out keys that match (in both lists).
  --dir <dir>       Folder to scan, relative to the project (repeatable;
                    default lib).
  --no-unused       Don't list unused keys.
  --fail            Exit with 1 when a key is missing (for CI).

Keys used: string literals before .tr, .trParams, .trArgs, .trCount (its
forms key.one, key.other…), .trPlural / .trPluralParams (and their plural
key). Dictionaries: the map of a Translations `keys` getter, the argument of
addTranslations / appendTranslations, translationsKeys:. Values may be map
literals, spreads, constants, or a constructor / Map.of call on one.''';
