import 'dart:ui';

/// A dictionary key split into language, script and country.
///
/// Keys are written `lang`, `lang_COUNTRY`, `lang_Script` or
/// `lang_Script_COUNTRY`, with `_` or `-` between the parts (`en_US`,
/// `en-US`, `zh_Hant_TW`). The language is compared without case, so
/// `persian_US` and made-up languages work too.
class LocaleKey {
  const LocaleKey(this.language, this.script, this.country);

  final String language;
  final String? script;
  final String? country;

  factory LocaleKey.parse(String key) {
    final parts = key.split(RegExp('[_-]'));
    String? script, country;
    for (final part in parts.skip(1)) {
      if (part.isEmpty) continue;
      if (script == null && country == null && _isScript(part)) {
        script = _titleCase(part);
      } else {
        country ??= part.toUpperCase();
      }
    }
    return LocaleKey(parts.first.toLowerCase(), script, country);
  }

  factory LocaleKey.of(Locale locale) {
    // `Locale('en_US')` (the whole tag in the language code) reads as en_US.
    final inLanguage = LocaleKey.parse(locale.languageCode);
    return LocaleKey(
      inLanguage.language,
      _nonEmpty(locale.scriptCode) ?? inLanguage.script,
      _nonEmpty(locale.countryCode)?.toUpperCase() ?? inLanguage.country,
    );
  }

  bool matches(String language, String? script, String? country) =>
      this.language == language &&
      this.script == script &&
      this.country == country;

  static bool _isScript(String part) =>
      part.length == 4 && RegExp(r'^[A-Za-z]{4}$').hasMatch(part);

  static String _titleCase(String s) =>
      s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
}

/// One dictionary in the lookup order, with the key it was added under (its
/// language, for plural rules).
typedef ChainEntry = ({String key, Map<String, String> dict});

/// The dictionaries `.tr` looks in, in order, for [locale] then
/// [fallbackLocale]:
///
/// 1. the exact `lang_Script_COUNTRY`,
/// 2. `lang_Script`, then `lang_COUNTRY`, then the bare `lang`,
/// 3. (the locale only) every other dictionary of the same language, those
///    with the same script first, in the order they were added.
///
/// Then the fallback locale's steps 1-2. With no locale, only the fallback.
/// Each dictionary appears once; dictionaries are used as given (a custom
/// `Map` keeps answering through its `[]`).
List<ChainEntry> buildChain(
  Map<String, Map<String, String>> translations,
  Locale? locale,
  Locale? fallbackLocale,
) {
  final entries = [
    for (final e in translations.entries)
      (LocaleKey.parse(e.key), (key: e.key, dict: e.value)),
  ];
  final result = <ChainEntry>[];

  void add(ChainEntry entry) {
    for (final r in result) {
      if (identical(r.dict, entry.dict)) return;
    }
    result.add(entry);
  }

  void addWhere(bool Function(LocaleKey key) test) {
    for (final (key, entry) in entries) {
      if (test(key)) add(entry);
    }
  }

  void ladder(Locale l, {required bool siblings}) {
    final k = LocaleKey.of(l);
    final lang = k.language, script = k.script, country = k.country;
    addWhere((key) => key.matches(lang, script, country));
    if (script != null) addWhere((key) => key.matches(lang, script, null));
    if (country != null) addWhere((key) => key.matches(lang, null, country));
    addWhere((key) => key.matches(lang, null, null));
    if (!siblings) return;
    if (script != null) {
      addWhere((key) => key.language == lang && key.script == script);
    }
    addWhere((key) => key.language == lang);
  }

  if (locale != null) ladder(locale, siblings: true);
  if (fallbackLocale != null) ladder(fallbackLocale, siblings: false);
  return result;
}
