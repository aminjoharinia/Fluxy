import 'args.dart';
import 'locales.dart';
import 'plural.dart';

extension Trans on String {
  /// The translation of this key in the current locale, falling back to
  /// other dictionaries of the same language, then to the fallback locale,
  /// then to the key itself (the order is in `I18N-PLAN.md` / the README).
  ///
  /// Inside an `Obx`, the `Obx` rebuilds when the locale or the dictionaries
  /// change.
  String get tr {
    final host = FluxyLocales.instance;
    final value = host.lookup(this);
    if (value != null) return value;
    host.reportMissing(this);
    return this;
  }

  /// Replaces each `%s` in the translation with the next of [args], in one
  /// pass (inserted values are not scanned again).
  String trArgs([List<String> args = const []]) => fillArgs(tr, args);

  /// Replaces `@name` placeholders in the translation with [params]: whole
  /// names only, the longest first, in one pass. Names may contain `-`.
  String trParams([Map<String, String> params = const {}]) =>
      fillParams(tr, params);

  /// The translation in the plural form for [count], chosen by the CLDR
  /// rules of the language it is translated into.
  ///
  /// The forms are entries next to the key: `'items.one'`, `'items.other'`,
  /// and for languages that have them `'items.two'`, `'items.few'`,
  /// `'items.many'`, `'items.zero'`. `'items.zero'` is also used for a count
  /// of 0 in any language ("No items"). A missing form falls back to
  /// `'items.other'`, then to `'items'` itself. `@count` is replaced with
  /// [count], and `@name` placeholders with [params].
  ///
  /// ```dart
  /// 'en_US': {'items.one': '@count item', 'items.other': '@count items'},
  /// 'ru_RU': {'items.one': '@count файл', 'items.few': '@count файла',
  ///           'items.many': '@count файлов', 'items.other': '@count файла'},
  /// 'items'.trCount(3) // "3 items"
  /// ```
  String trCount(num count, [Map<String, String> params = const {}]) {
    final text = FluxyLocales.instance.lookupPlural(this, count) ?? tr;
    return fillParams(text, {'count': '$count', ...params});
  }

  /// This key's translation when [i] is in the language's `one` category,
  /// else [pluralKey]'s (CLDR rules: in French and Persian 0 is `one` too).
  /// With no [pluralKey], always this key's. `%s` is filled from [args].
  ///
  /// For languages with more than two forms use [trCount].
  String trPlural([String? pluralKey, int? i, List<String> args = const []]) =>
      _singular(pluralKey, i) ? trArgs(args) : pluralKey!.trArgs(args);

  /// [trPlural] with `@name` placeholders filled from [params].
  String trPluralParams([
    String? pluralKey,
    int? i,
    Map<String, String> params = const {},
  ]) =>
      _singular(pluralKey, i) ? trParams(params) : pluralKey!.trParams(params);

  bool _singular(String? pluralKey, int? i) =>
      pluralKey == null ||
      (i != null &&
          FluxyLocales.instance.categoryFor(this, i) == PluralCategory.one);
}
