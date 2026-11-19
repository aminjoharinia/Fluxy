import 'locales.dart';

extension Trans on String {
  /// The translation of this key in the current locale, falling back to
  /// other dictionaries of the same language, then to the fallback locale,
  /// then to the key itself (the order is in `I18N-PLAN.md` / the README).
  ///
  /// Inside an `Obx`, the `Obx` rebuilds when the locale or the dictionaries
  /// change.
  String get tr => FluxyLocales.instance.lookup(this) ?? this;

  /// Replaces each `%s` in the translation with the next of [args].
  String trArgs([List<String> args = const []]) {
    var key = tr;
    for (final arg in args) {
      key = key.replaceFirst('%s', arg);
    }
    return key;
  }

  String trPlural([String? pluralKey, int? i, List<String> args = const []]) {
    return i == 1 ? trArgs(args) : pluralKey!.trArgs(args);
  }

  /// Replaces `@name` placeholders in the translation with [params].
  ///
  /// One pass over the text: a placeholder only matches a whole name (so
  /// `@admin` does not eat the start of `@admin_email`; the longest matching
  /// name wins), and inserted values are never scanned again (a value that
  /// contains `@other` stays as it is). Names may contain `-`.
  String trParams([Map<String, String> params = const {}]) {
    final text = tr;
    if (params.isEmpty || !text.contains('@')) return text;
    final names = params.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final at = text.indexOf('@', i);
      if (at < 0) break;
      out.write(text.substring(i, at));
      String? matched;
      for (final name in names) {
        final end = at + 1 + name.length;
        if (text.startsWith(name, at + 1) &&
            (end == text.length || !_isNameChar(text.codeUnitAt(end)))) {
          matched = name;
          break;
        }
      }
      if (matched == null) {
        out.write('@');
        i = at + 1;
      } else {
        out.write(params[matched]);
        i = at + 1 + matched.length;
      }
    }
    out.write(text.substring(i));
    return out.toString();
  }

  String trPluralParams([
    String? pluralKey,
    int? i,
    Map<String, String> params = const {},
  ]) {
    return i == 1 ? trParams(params) : pluralKey!.trParams(params);
  }
}

/// ASCII letters, digits and `_`: characters that continue a placeholder name.
bool _isNameChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F; // _
