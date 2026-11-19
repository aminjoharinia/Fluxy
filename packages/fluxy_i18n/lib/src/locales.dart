import 'dart:ui';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

import 'lookup.dart';
import 'plural.dart';

/// The app's language state: the locale, the fallback locale and the
/// dictionaries, in one place. Plain Dart; fluxy_nav wires it to the app.
///
/// `locale` and `fallbackLocale` are reactive: an `Obx` (or `Computed`) that
/// reads them rebuilds when they change. `.tr` subscribes through [version],
/// which also moves when the dictionaries change.
class FluxyLocales {
  FluxyLocales._();

  static final FluxyLocales instance = FluxyLocales._();

  final Rxn<Locale> _locale = Rxn<Locale>();
  final Rxn<Locale> _fallbackLocale = Rxn<Locale>();

  /// The loaded dictionaries, by key as given ("lang_COUNTRY", "lang",
  /// "en-US", "zh_Hant"...). Stored as given, never copied.
  final Map<String, Map<String, String>> translations = {};

  /// Bumped on every locale or dictionary change.
  final RxInt version = 0.obs;

  List<ChainEntry>? _chain;

  Locale? get locale => _locale.value;
  set locale(Locale? value) {
    if (_locale.peek == value) return;
    _locale.value = value;
    changed();
  }

  Locale? get fallbackLocale => _fallbackLocale.value;
  set fallbackLocale(Locale? value) {
    if (_fallbackLocale.peek == value) return;
    _fallbackLocale.value = value;
    changed();
  }

  /// Forgets the cached lookup order and tells `.tr` readers.
  void changed() {
    _chain = null;
    version.value = version.peek + 1;
  }

  /// The dictionaries `.tr` looks in, in order (see [buildChain]). Built on
  /// first use after a change.
  List<ChainEntry> get chain => _chain ??=
      buildChain(translations, _locale.peek, _fallbackLocale.peek);

  /// The translation of [key], or null when no dictionary has it.
  /// Subscribes the running `Obx` / `Computed`, if any.
  String? lookup(String key) {
    version.value;
    for (final entry in chain) {
      final value = entry.dict[key];
      if (value != null) return value;
    }
    return null;
  }

  /// The plural form of [key] for [count]: in each dictionary of the chain,
  /// `key.zero` when [count] is 0 (any language), then `key.<category>` by
  /// that dictionary's language rules, then `key.other`. Null when no
  /// dictionary has a form.
  String? lookupPlural(String key, num count) {
    version.value;
    for (final entry in chain) {
      final dict = entry.dict;
      String? value;
      if (count == 0) value = dict['$key.zero'];
      value ??= dict['$key.${pluralCategory(entry.key, count).name}'];
      value ??= dict['$key.other'];
      if (value != null) return value;
    }
    return null;
  }

  /// The plural category of [count] in the language [key] is translated
  /// into: the first dictionary that has [key], else the locale (or the
  /// fallback locale), else English rules.
  PluralCategory categoryFor(String key, num count) {
    version.value;
    for (final entry in chain) {
      if (entry.dict[key] != null) return pluralCategory(entry.key, count);
    }
    final l = _locale.peek ?? _fallbackLocale.peek;
    return pluralCategory(l?.toLanguageTag() ?? 'en', count);
  }

  /// Clears the dictionaries and both locales. For tests (`Fluxy.reset()`).
  void reset() {
    translations.clear();
    _locale.value = null;
    _fallbackLocale.value = null;
    changed();
  }
}

extension LocalesIntl on FluxyInterface {
  static FluxyLocales get _host => FluxyLocales.instance;

  /// The language `.tr` translates into. Reactive: an `Obx` that reads it
  /// rebuilds when it changes.
  Locale? get locale => _host.locale;

  /// Where `.tr` looks when the locale's dictionaries don't have a key (also
  /// when no locale is set). Reactive.
  Locale? get fallbackLocale => _host.fallbackLocale;

  /// Setting it updates every `Obx` that shows `.tr` text. Widgets that read
  /// `.tr` outside an `Obx` need a rebuild; `Fluxy.updateLocale` does that.
  set locale(Locale? newLocale) => _host.locale = newLocale;

  set fallbackLocale(Locale? newLocale) => _host.fallbackLocale = newLocale;

  /// The loaded dictionaries, by key ("lang_COUNTRY", "lang", "en-US"...),
  /// stored as they were added. After changing this map directly, call
  /// [notifyTranslationsChanged].
  Map<String, Map<String, String>> get translations => _host.translations;

  /// Incremented on every locale or translation change. Reading it inside an
  /// `Obx` subscribes to language changes (`.tr` already does this).
  RxInt get translationVersion => _host.version;

  /// Call after changing [translations] directly.
  void notifyTranslationsChanged() => _host.changed();

  /// Adds dictionaries, replacing any existing dictionary with the same key.
  ///
  /// Each map is kept as given, not copied: a custom `Map` (one that answers
  /// keys it doesn't list, for templates) goes on working, since `.tr` only
  /// calls its `[]`. Fluxy never writes into it.
  void addTranslations(Map<String, Map<String, String>> tr) {
    translations.addAll(tr);
    _host.changed();
  }

  void clearTranslations() {
    translations.clear();
    _host.changed();
  }

  /// Merges [tr] into the existing dictionaries, key by key. Works when the
  /// existing or the new maps are `const`: the result is a new plain map
  /// (so appending to a custom `Map` turns it into a plain one).
  void appendTranslations(Map<String, Map<String, String>> tr) {
    tr.forEach((key, map) {
      final existing = translations[key];
      translations[key] =
          existing == null ? Map.of(map) : ({...existing, ...map});
    });
    _host.changed();
  }

  /// Clears the dictionaries, the locale and the fallback locale.
  /// `Fluxy.reset()` calls it; for tests.
  void resetLocales() => _host.reset();
}
