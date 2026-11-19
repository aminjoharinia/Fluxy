# fluxy_i18n

Translations for Fluxy apps: dictionaries, the app's locale, `'key'.tr` (reactive inside `Obx`), placeholders, plurals, native digits and the text-direction rule. `Fluxy.updateLocale` and the `FluxyApp` wiring live in fluxy_nav, since they rebuild the app.

Depends on: fluxy_core, fluxy_state (for reactive `.tr`). Rebuilt in v1.7.0.

## Setting up

```dart
class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {'save': 'Save', 'hello': 'Hello @name'},
    'fa_IR': {'save': 'ذخیره', 'hello': 'سلام @name'},
  };
}

FluxyApp(
  translations: Messages(),
  locale: const Locale('fa', 'IR'),
  fallbackLocale: const Locale('en', 'US'),
  home: const HomePage(),
);

Text('save'.tr);
Text('hello'.trParams({'name': user.name}));
Fluxy.updateLocale(const Locale('en', 'US'));
```

Dictionaries can also be added before `runApp` (`Fluxy.addTranslations`, `Fluxy.locale = ...`); they stay when the `FluxyApp` is disposed and mounted again. `Fluxy.reset()` clears dictionaries, locales and the rules below, for tests.

## Lookup order

Dictionary keys are `lang`, `lang_COUNTRY`, `lang_Script` or `lang_Script_COUNTRY`, with `_` or `-` (`en_US`, `en-US`, `zh_Hant_TW`); the language is compared without case, so made-up codes (`persian_US`) work too. `.tr` looks in:

1. the locale's exact dictionary,
2. its `lang_Script`, then `lang_COUNTRY`, then the bare `lang`,
3. every other dictionary of the same language (same script first), in the order they were added,
4. the fallback locale's exact, then bare dictionary (also when no locale is set),

and returns the key itself when none has it. The order is worked out once per change of locale or dictionaries, not on every `.tr`.

**Dictionaries are kept as given, never copied.** A custom `Map` works: `.tr` only calls its `[]`, so a map that answers keys it doesn't list (templates, a database, a cache) keeps answering. Here an English dictionary answers `'مانده: ۱۲۰'` from the template `'مانده: {0}'`:

```dart
class EnglishTranslations extends MapBase<String, String> {
  @override
  String? operator [](Object? key) => _exact[key] ?? _fromTemplate(key);
  // keys, []=, remove, clear ...
}

Fluxy.addTranslations({'en_US': EnglishTranslations(kEnglishDictionary)});
```

`appendTranslations` merges key by key into a new plain map (so don't append to a custom one). After editing `Fluxy.translations` directly, call `Fluxy.notifyTranslationsChanged()`.

## Reactivity

`Fluxy.locale`, `Fluxy.fallbackLocale` and `Fluxy.textDirection` are reactive, and so is `.tr` (it reads `Fluxy.translationVersion`): an `Obx` or `Computed` that reads them rebuilds when the language or the dictionaries change. Setting `Fluxy.locale` alone also updates the locale Material / Cupertino get.

Text read outside an `Obx` (a `.tr` in a plain `build`, a `const` widget) needs a rebuild: `Fluxy.updateLocale(locale)` rebuilds every widget once by marking it (no hot-reload hook, no `State.reassemble`) and completes after that frame. `updateLocale(locale, rebuildAll: false)` skips that when all translated text is in `Obx`.

## Placeholders

- `trParams({'name': 'Ann'})` replaces `@name`: whole names only (`@admin` doesn't eat `@admin_email`), the longest first, in one pass (an inserted value is never replaced again). Names may contain `-`.
- `trArgs(['a', 'b'])` replaces `%s` in order, in one pass; leftover `%s` stay.

## Plurals

`'files'.trCount(n, [params])` picks the form for `n` by the CLDR plural rules of the language the text is in, and fills `@count`:

```dart
'en_US': {
  'files.zero': 'No files',          // optional: n == 0 in any language
  'files.one': '@count file',
  'files.other': '@count files',
},
'ru_RU': {
  'files.one': '@count файл',        // 1, 21, 101
  'files.few': '@count файла',       // 2-4, 22-24
  'files.many': '@count файлов',     // 0, 5-20, 25
  'files.other': '@count файла',     // 1.5
},
'ar': {'files.zero': ..., 'files.one': ..., 'files.two': ..., 'files.few': ..., 'files.many': ..., 'files.other': ...},
```

A missing form falls back to `files.other`, then to `files` itself. The rules are a built-in table (no `intl` dependency) for English-like languages, Persian (0 and 1 are `one`), French and Brazilian Portuguese, Russian / Ukrainian / Belarusian, Polish, Czech / Slovak, Arabic, Hebrew, Romanian, Croatian / Serbian / Bosnian, Lithuanian, Latvian, and languages with no plural (Chinese, Japanese, Korean, Thai, Vietnamese, Indonesian…); others use the English rule. `pluralCategory(language, n)` gives the category directly.

The two-key `trPlural('items', n, args)` / `trPluralParams('items', n, params)` still work: the key's text when `n` is in the language's `one` category, else the plural key's.

## Text direction

**The language never sets the text direction by itself.** A `FluxyApp` is left-to-right in every language, Persian and Arabic included, because Persian screens and texts are often left-to-right (numbers, codes, mixed English, layouts built on purpose). The app decides:

```dart
FluxyApp(textDirection: TextDirection.rtl, ...)          // fixed
FluxyApp(directionFor: (l) => rtlLanguages.contains(l.languageCode)
    ? TextDirection.rtl : TextDirection.ltr, ...)        // per language
```

`Fluxy.textDirection` reads the result anywhere (reactive), and it is the root `Directionality`. `rtlLanguages` is a list of usually right-to-left language codes for such a rule; Fluxy never applies it.

## Digits

```dart
'12:30'.localDigits()         // ۱۲:۳۰ in Persian, ١٢:٣٠ in Arabic, 12:30 in English
total.localDigits()           // num
int.parse(input.westernDigits) // '۱۴۰۵' -> 1405
```

`localDigits` uses the language's CLDR default digits (default locale: `Fluxy.locale`, reactive): Extended Arabic-Indic for Persian (and `persian`) and Pashto, Arabic-Indic for Arabic (Western in the Maghreb) and Sorani, Devanagari for Marathi and Nepali, Bengali, Burmese; English, Urdu, Hindi and the rest keep 0-9. `westernDigits` turns every native digit set back into 0-9.

## Missing keys

```dart
FluxyApp(
  onMissingTranslation: (key, locale) {
    if (kDebugMode) debugPrint('no translation for "$key" in $locale');
  },
  ...
);
```

Called once per key (until the language or the dictionaries change) when no dictionary has it; a key the fallback has isn't missing. It runs during a build: log or collect only. An app whose keys are the text of one language skips that locale.

To check a whole app ahead of time: `dart run tool/i18n_check.dart <app> [--locale en_US] [--fail]` lists keys used in code but missing from each dictionary, and dictionary keys no code uses (see [tool/README.md](../../tool/README.md)).

## Coming from GetX

| GetX | Fluxy |
|---|---|
| `fa` / `ar` / `he` / `ps` / `ur` turned the whole app right-to-left | left-to-right unless `FluxyApp(textDirection:)` / `directionFor:` (apps used `Locale('persian', 'US')` to avoid the flip; they can use `fa_IR` now) |
| `Get.updateLocale` reassembled the app (hot-reload hook) | marks every widget for one rebuild; completes after that frame |
| `Get.locale` not reactive | `Fluxy.locale` reactive; setting it alone updates Material's locale |
| `addTranslations` copied each map | maps kept as given (custom `Map`s work, as in GetX 4) |
| only the last dictionary of the language was searched; script codes ignored | the lookup order above |
| no locale: the fallback ignored | the fallback answers |
| `trPlural`: `n == 1`, throws without a plural key | CLDR `one` category, singular without a plural key; `trCount` for more forms |
| an app without `locale:` showed keys until the device language changed | starts in the device language |

Part of [Fluxy](../../FLUXY.md), a fork of GetX (MIT, © Jonny Borges).
