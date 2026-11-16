import 'dart:ui';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

class _IntlHost {
  Locale? _locale;
  Locale? _fallbackLocale;
  final Map<String, Map<String, String>> translations = {};

  /// Bumped on every locale or dictionary change. `.tr` reads it, so an
  /// `Obx` that shows translated text rebuilds when the language changes.
  final RxInt version = 0.obs;

  /// The dictionaries `.tr` looks in, in order, for the current locale.
  /// Built on first use after a change instead of on every `.tr` call.
  List<Map<String, String>>? _chain;

  Locale? get locale => _locale;
  set locale(Locale? value) {
    _locale = value;
    changed();
  }

  Locale? get fallbackLocale => _fallbackLocale;
  set fallbackLocale(Locale? value) {
    _fallbackLocale = value;
    changed();
  }

  void changed() {
    _chain = null;
    version.value = version.peek + 1;
  }

  List<Map<String, String>> get chain => _chain ??= _buildChain();

  // Same lookup order as before the cache:
  // 1. "lang_country" of the locale
  // 2. any dictionary whose language part matches (the last one wins)
  // 3. "lang_country" of the fallback locale
  // 4. "lang" of the fallback locale
  List<Map<String, String>> _buildChain() {
    final result = <Map<String, String>>[];
    void addIfPresent(Map<String, String>? dict) {
      if (dict != null && !result.any((d) => identical(d, dict))) {
        result.add(dict);
      }
    }

    final locale = _locale;
    if (locale == null) return result;
    addIfPresent(translations['${locale.languageCode}_${locale.countryCode}']);

    final language = locale.languageCode.split('_').first;
    Map<String, String>? similar;
    translations.forEach((key, dict) {
      if (key.split('_').first == language) similar = dict;
    });
    addIfPresent(similar);

    final fallback = _fallbackLocale;
    if (fallback != null) {
      addIfPresent(
          translations['${fallback.languageCode}_${fallback.countryCode}']);
      addIfPresent(translations[fallback.languageCode]);
    }
    return result;
  }
}

extension LocalesIntl on FluxyInterface {
  static final _intlHost = _IntlHost();

  Locale? get locale => _intlHost.locale;

  Locale? get fallbackLocale => _intlHost.fallbackLocale;

  /// Setting it updates every `Obx` that shows `.tr` text. Widgets that read
  /// `.tr` outside an `Obx` need a rebuild; `Fluxy.updateLocale` does that.
  set locale(Locale? newLocale) => _intlHost.locale = newLocale;

  set fallbackLocale(Locale? newLocale) => _intlHost.fallbackLocale = newLocale;

  /// The loaded dictionaries, by locale key ("lang_country" or "lang").
  /// After changing this map directly, call [notifyTranslationsChanged].
  Map<String, Map<String, String>> get translations => _intlHost.translations;

  /// Incremented on every locale or translation change. Reading it inside an
  /// `Obx` subscribes to language changes (`.tr` already does this).
  RxInt get translationVersion => _intlHost.version;

  /// Call after changing [translations] directly.
  void notifyTranslationsChanged() => _intlHost.changed();

  /// Adds dictionaries, replacing any existing dictionary with the same key.
  void addTranslations(Map<String, Map<String, String>> tr) {
    tr.forEach((key, map) => translations[key] = Map.of(map));
    _intlHost.changed();
  }

  void clearTranslations() {
    translations.clear();
    _intlHost.changed();
  }

  /// Merges [tr] into the existing dictionaries, key by key. Works when the
  /// existing or the new maps are `const`: both are copied, never modified.
  void appendTranslations(Map<String, Map<String, String>> tr) {
    tr.forEach((key, map) {
      final existing = translations[key];
      translations[key] =
          existing == null ? Map.of(map) : ({...existing, ...map});
    });
    _intlHost.changed();
  }
}

extension Trans on String {
  /// The translation of this key in the current locale, falling back to the
  /// same language in another country, then to the fallback locale, then to
  /// the key itself.
  ///
  /// Inside an `Obx`, the `Obx` rebuilds when the locale or the dictionaries
  /// change.
  String get tr {
    final host = LocalesIntl._intlHost;
    host.version.value; // subscribe the building Obx, if any
    for (final dict in host.chain) {
      final value = dict[this];
      if (value != null) return value;
    }
    return this;
  }

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
