# fluxy_i18n re-engineering plan

Status: phases 0-4 done (2026-11-19), phase 5 (files and docs) next. Decisions at the end.

## Why

fluxy_i18n is still GetX's design with a cache in front: one static host, a flat `Map<String, Map<String, String>>` keyed by `"lang_country"`, a reactive version counter for `.tr`, and the language switch done by fluxy_nav through a hot-reload hook. v0.5 made `.tr` reactive and v1.6 made a rebuilt `FluxyApp` take a new locale; nothing else was redesigned. The bugs below were confirmed with throwaway tests on v1.6.1:

| # | Bug | Cause |
|---|---|---|
| B1 | `addTranslations` / `FluxyApp(translations:)` copy each dictionary with `Map.of`, so a custom `Map` (Hesabak's `EnglishTranslations`, a `MapBase` that also answers template keys like `'مانده: {0}'`) becomes a plain map: in English, every interpolated line loses its translation. GetX 4 kept the map object | `tr.forEach((key, map) => translations[key] = Map.of(map))` |
| B2 | With no `Fluxy.locale` but a `fallbackLocale`, `.tr` ignores the fallback and returns the key | `_buildChain` returns early when the locale is null |
| B3 | A `FluxyApp` without `locale:` (it follows the device) starts with `Fluxy.locale == null`, so every `.tr` shows its key until the device language changes | The device locale is read only in `didChangeLocales`, never at mount |
| B4 | `Locale('zh', 'TW')` with script `Hant` and dictionaries `zh_Hant` / `zh_Hans` gets `zh_Hans` | Script codes are ignored; "any dictionary of the same language, the last one wins" |
| B5 | `pt_BR` with `pt_PT` and `pt` registered: the answer depends on registration order (`pt` or `pt_PT`) | Same rule; a bare `pt` should win over a sibling country |
| B6 | Dictionaries keyed BCP 47 style (`en-US`) are never found | Keys are only `lang_country` / `lang` |
| B7 | `trArgs(['50%s', 'B'])` on `'%s and %s'` gives `50B and %s` | Inserted values are scanned again (`replaceFirst` in a loop); `trParams` was fixed for this in v0.5, `trArgs` wasn't |
| B8 | `trPlural(null, 2)` / `trPluralParams(null, 2)` throw a `TypeError`; plurals are "1 or not 1" for every language (wrong for Arabic, Russian, Polish…; `0` takes the plural key) | `pluralKey!`, `i == 1` |
| B9 | An `Obx` that reads `Fluxy.locale` (or the app's text direction) never rebuilds, and throws "improper use" when that is its only read | `locale` is a plain field; only the `.tr` version counter is an `Rx` |
| B10 | `Fluxy.reset()` clears translations but keeps `locale` / `fallbackLocale`: tests leak the language into the next test | `reset` calls `clearTranslations` only |
| ~~B11~~ | Withdrawn in phase 0: `await Fluxy.updateLocale(l)` inside `testWidgets` waits for a frame nobody pumps; started without `await` and pumped, it completes. Not a bug | — |
| B12 | `FluxyApp(locale: Locale('fa', 'IR'))` turns the whole app right-to-left while Material resolves to `en_US` if `fa` isn't in `supportedLocales`: `.tr`, direction and Material strings can disagree | Direction comes from `rtlLanguages.contains(Fluxy.locale?.languageCode)`, Material from its own resolution |

Design debt behind those:

- **The language switch is a hot reload.** `updateLocale` (default `rebuildAll: true`) calls `performReassemble`: every `State.reassemble` runs (a hot-reload hook), every element rebuilds and every render object is marked for layout and paint. It's the only way GetX had to reach `.tr` in plain `build` methods.
- **Language, dictionary key, direction and Flutter locale are one value.** All three apps work around it with a made-up `Locale('persian', 'US')`: Flutter doesn't treat it as right-to-left (the apps lay out direction themselves: 154 / 506 / 124 `textDirection:` in BOOFI / Hesabak / NestCut), and Material falls back to whatever comes first in `supportedLocales`. Each app then keeps its own `isEnglish` / `appTextDirection` / `authDirection` getter.
- **Dictionaries are maps of strings only.** No plurals, no select, no named lookup rules, no loading per language (BOOFI's `Languages.dart` is 2,584 lines, all in memory). Hesabak builds template lookup on top by subclassing `Map`, relying on undocumented internals (B1 broke it).
- **Locale state lives in two packages.** fluxy_i18n holds `locale` / translations; fluxy_nav holds `updateLocale`, `followDeviceLocale`, the root `Directionality` and the Material `locale:`; `rtlLanguages` (5 entries, missing `ckb`, `dv`, `sd`, `ug`, `yi`) is read from both `FluxyApp` and `FluxyCupertinoApp`.
- **Number and digit formatting is app code.** NestCut's `localDigits` (14 calls), BOOFI and Hesabak use `…FaNum` fonts to show Persian digits.

## What the apps use (keep these working)

| | BOOFI | Hesabak | NestCut |
|---|---|---|---|
| `.tr` | 1,789 | 2,303 | 756 |
| `.trParams` | 27 | 0 | 128 |
| `trArgs` / `trPlural*` | 0 | 0 | 0 |
| Dictionaries | `Messages`: `en_US`, `persian_US` (+ a stray `de_DE`) | `en_US` (custom `MapBase` with `{0}` templates), `persian_US` (small); Persian text is the key | `Messages`: `en_US`, `persian_US` |
| Language switch | `Fluxy.updateLocale` (sets the font first) | `Fluxy.updateLocale` | `Get.updateLocale`, the whole `GetMaterialApp` in an `Obx` |
| Other | `fallbackLocale: persian_US`, `DefaultMaterialLocalizations` only | `supportedLocales: [fa_IR, en_US]`, `GlobalMaterialLocalizations` | `Get.addTranslations` + `Get.locale` set in `main()` before `runApp` |

Nobody uses `trArgs`, `trPlural`, `appendTranslations`, `translationVersion`, `rtlLanguages` or `deviceLocale` directly.

## Target design

Same everyday API (`'key'.tr`, `.trParams`, `Translations`, `FluxyApp(translations:, locale:, fallbackLocale:)`, `Fluxy.updateLocale`), new internals.

1. **`FluxyLocales`: one reactive locale state, plain Dart.** `locale`, `fallbackLocale` and the resolved `textDirection` are `Rx` values (B9), set from one place. It also owns the dictionary registry and a `version` bump for dictionary edits. `Fluxy.locale` / `fallbackLocale` / `translations` stay as facade getters. `Fluxy.reset()` resets all of it (B10).
2. **Lookup by a resolved chain, computed once per change.** For a locale `lang_Script_COUNTRY`: exact, `lang_Script`, `lang_COUNTRY`, `lang`, then any `lang_*` in registration order, then the same for the fallback locale (also when the locale is null, B2). Keys are normalized on registration, so `en-US`, `en_US` and `Locale('en', 'US')` are one key (B4-B6). Dictionaries are stored as given, never copied (B1): `[]` is the only call made on them (documented, tested with a `MapBase`). `appendTranslations` keeps copying, since merging needs a new map.
3. **The switch without a hot reload.** `.tr` stays context-free. The root (`FluxyRoot`) reads `FluxyLocales` through an `Obx`-like subscription and passes `locale` / `textDirection` down through `Localizations` and `Directionality`, so widgets that call `Localizations.localeOf(context)` / `Directionality.of(context)` rebuild the Flutter way. Plain `build` methods that read `.tr` still need a full rebuild: done by marking every element dirty once (no `State.reassemble`, no forced relayout), behind the same `updateLocale(l, {rebuildAll = true})`. `updateLocale` completes after that frame.
4. **Direction is the app's choice, never the language's** (D2). The root is left-to-right unless the app passes `FluxyApp(textDirection:)` (fixed) or `directionFor: (Locale) => TextDirection`; `Fluxy.textDirection` is reactive. Apps can then use the real `Locale('fa', 'IR')` with no layout change. This retires the `persian_US` workaround: one rename in each app's dictionary key and locale constants.
5. **Material locale agrees with `.tr`.** The locale given to `MaterialApp` / `CupertinoApp` is `Fluxy.locale`; in debug, a warning when it isn't in `supportedLocales` and Flutter falls back to another one (B12).
6. **Arguments and plurals.** `trArgs` in one pass (B7). `trCount(count, [params])` picks the form by CLDR plural rules for the language of the dictionary that answers (`zero`, `one`, `two`, `few`, `many`, `other`), read from keys `key.one`, `key.other`…, `key.zero` also for a count of 0 in any language, then `key.other`, then `key`; `@count` filled in. The old `trPlural(pluralKey, i, args)` / `trPluralParams` keep their signatures: singular when `i` is in the `one` category, and a null plural key gives the singular (B8). Rules per D1.
7. **Optional loading per language** (D3). `Translations` may override `Future<Map<String, String>> load(Locale)`; `FluxyApp` loads the chain for the start locale before the first frame and `updateLocale` awaits the new one. In-memory `keys` stays the default.
8. **Missing keys.** `FluxyApp(onMissingTranslation: (key, locale) {...})`, debug only by default, so an app can log keys missing in English while Persian-as-key stays silent. A `tool/i18n_check.dart` (D4) lists `.tr` literals with no entry in a given dictionary and entries no code uses.
9. **Digits** (D5). `Fluxy.localDigits(String)` / `'12'.localDigits`: Western digits to the current language's native digits (Persian, Arabic, Hindi…), no change for Latin-digit languages.
10. **Files.** `packages/fluxy_i18n/lib/src/{locales,lookup,plural,args,digits}.dart`; `rtlLanguages` and the direction default move into fluxy_i18n; fluxy_nav keeps only the widget wiring (`updateLocale`, `followDeviceLocale`, root `Localizations` / `Directionality`). The device locale is read at mount (B3).

Kept as is: `Translations.keys`, `.tr` / `.trParams` behaviour for a found key (BOOFI's and NestCut's `@name` placeholders), `addTranslations` / `appendTranslations` / `clearTranslations` / `notifyTranslationsChanged`, `followDeviceLocale` rules, `FluxyApp(translationsKeys:)`, a rebuilt `FluxyApp` not re-reading translations (APP-NOTES 14).

## Phases

Each phase ends green: every package, both examples, root, tool, and the three app copies (`pubspec_overrides.yaml`; BOOFI's 97 tests, Hesabak's and NestCut's suites once moved). One release at the end.

0. **Characterization tests.** Pin what the apps rely on: `persian_US` locale with an `en_US` fallback, Persian-as-key returning the key, `@name` params, `updateLocale` reaching `.tr` in `Obx` and in plain `build` and const widgets, an app in an `Obx` passing a new locale, `main()` setting `Fluxy.locale` before `runApp`. B1-B12 as tests, `skip` until fixed.

1. **`FluxyLocales` and lookup.** Reactive state, normalized keys, the new chain, no copying, `reset`. Fixes B1, B2, B4-B6, B9, B10.
2. **Arguments and plurals.** One-pass `trArgs`, CLDR rules, old signatures fixed. Fixes B7, B8.
3. **Switch and direction.** Root wiring in fluxy_nav, rebuild without reassemble, `directionFor`, device locale at mount, `supportedLocales` warning. Fixes B3, B12 (and D2). Measure a language switch on a big screen (benchmark app, BOOFI-sized tree) against v1.6.1.
4. **Extras per D3-D5**: loaders, `onMissingTranslation` + check tool, digits.
5. **Files and docs.** `lib/src/`, fluxy_i18n README (lookup order, plurals, direction, a custom-map example), FLUXY.md, "Coming from GetX" rows (`trPlural`, `rtlLanguages`, `updateLocale` no longer reassembles), APP-NOTES entries for the `persian_US` → `fa_IR` move in each app.
6. **Release.** Notes, tag, app switches (pubspec bumps; dictionary key and locale renames left to the user, like earlier app changes).

## Decisions

Decided 2026-11-19 (user's choice: the proposed defaults, with D2 changed).

- **D1: plural rules from a small built-in CLDR table** (the languages in use and the common ones), no `package:intl` dependency.
- **D2: the language never sets the text direction.** Persian (or any language) does not turn text right-to-left by itself: Persian screens and texts are often left-to-right (numbers, codes, mixed English, layouts the apps build on purpose). Fluxy's root `Directionality` is left-to-right unless the app asks: `FluxyApp(textDirection:)` (fixed) or `directionFor: (Locale) => TextDirection` (per language). `rtlLanguages` stays exported as data an app may use in its own `directionFor`, never applied by Fluxy. This replaces the GetX rule (`fa` / `ar` / `he` / `ps` / `ur` turned the whole app right-to-left) and is what lets the apps move from `persian_US` to `fa_IR` with no layout change. Breaking for an app that relied on the automatic flip: it passes `directionFor` (a "Coming from GetX" row).
- **D3: no loaders per language** for now (none of the three apps loads from assets); `Translations` stays in-memory.
- **D4: `tool/i18n_check.dart` is included.**
- **D5: the digits helper lives in fluxy_i18n** (it follows the language).
- **Version:** v1.7.0, breaking only where a fix changes an answer (B2-B5 change which dictionary wins; B8 changes `trPlural` for languages with more than two forms; D2 for apps that relied on the automatic right-to-left).

## Results

### Phase 0 (2026-11-19): characterization tests

- `packages/fluxy_i18n/test/characterization_test.dart` (13): the apps' shapes (BOOFI / NestCut `persian_US` + `en_US` with a Persian fallback, Hesabak's Persian-as-key, `@name` params with Persian digits, dictionaries set in `main()`, a missing key) pass; B1, B2, B4-B9 skipped (each fails today when un-skipped; B1 uses a Hesabak-style template `MapBase`).
- `packages/fluxy_nav/test/internationalization/characterization_test.dart` (10): `updateLocale` reaching `Obx`, plain and const widgets and a page under the top one, NestCut's app-in-`Obx` locale change, translations set before `runApp`, `persian_US` keeping the root left-to-right, `textDirection:` winning, `updateLocale` completing once pumped; B3, B10 and D2 / B12 (`fa_IR` keeps the root left-to-right) skipped, each failing today.
- B11 withdrawn (see the table).

### Phase 1 (2026-11-19): locale state and lookup

- `lib/src/locales.dart`: `FluxyLocales` (one instance, not exported) holds `locale` / `fallbackLocale` as `Rxn<Locale>`, the dictionaries and the `version` counter; setting the same locale again doesn't notify. `LocalesIntl` (the `Fluxy.` facade) moved there; `addTranslations` keeps each map as given (B1), `appendTranslations` still builds a new plain map; new `Fluxy.resetLocales()`, called by `Fluxy.reset()` (B10). `intl.dart` keeps only the `.tr` extensions.
- `lib/src/lookup.dart`: `LocaleKey` parses `lang[_-]Script[_-]COUNTRY` keys and locales (also a whole tag in `languageCode`); `buildChain` gives the order of target design item 2 (B2, B4-B6). Keys are parsed when the chain is built, so direct edits of `Fluxy.translations` with any spelling work after `notifyTranslationsChanged`.
- Behaviour changes pinned by updated tests: a locale with no exact dictionary searches every dictionary of its language in the order added (before: only the last one, so `en_AU` missed keys only in `en_US`); with no locale, the fallback locale answers.
- Tests: `lookup_test.dart` (12: key parsing, chain order, script siblings, fallback without siblings, identity, same-locale no-op, kept map objects, BCP 47 direct edit, reset, a `Computed` over `Fluxy.locale`); B1, B2, B4-B6, B9 (fluxy_i18n) and B10 (fluxy_nav) un-skipped. fluxy_i18n 39 + 2 skipped, fluxy_nav 250 + 2 skipped; every package, root and both examples analyze clean and pass. App copies on the local Fluxy (`pubspec_overrides.yaml`, copies in the session scratchpad, apps untouched): Hesabak analyze clean, 1,371 tests pass; BOOFI 97 tests pass and `lib` / `test` analyze clean once `FloorPlanCreate.dart` imports `VoidCallback` from `dart:ui` (a v1.6.0 change, not this phase: BOOFI is still on v1.5.0 and needs that one-line import when it moves).

### Phase 2 (2026-11-19): arguments and plurals

- `lib/src/plural.dart`: `PluralCategory` and `pluralCategory(language, count)` (exported), a built-in CLDR cardinal table (D1): English-like, `n = 1`, Persian-like (`i = 0 or n = 1`), French / Brazilian Portuguese, other-only (CJK, Thai, Vietnamese, Indonesian…), Russian / Ukrainian / Belarusian, Polish, Czech / Slovak, Arabic, Hebrew, Romanian, Croatian / Serbian / Bosnian, Lithuanian, Latvian; unknown languages use the English rule; `persian` / `farsi` read as `fa`, `pt_PT` as English. Operands n / i / v / f, so `1.5` and `1.0` are counted as CLDR does.
- `lib/src/args.dart`: `fillArgs` (one pass, B7) and `fillParams` (the v0.5 `trParams` scan, moved). `intl.dart`: `trCount` (new), `trPlural` / `trPluralParams` on the CLDR `one` category with a null plural key giving the singular (B8). The lookup chain now carries each dictionary's key, so a form is chosen by the rules of the language that answers (a fallback dictionary uses its own).
- Tests: `plural_test.dart` (16: rules per language with edge counts, `trCount` in English / Russian / Arabic / Persian, fallback rules, params, an `Obx` following the locale, the two-key `trPlural`, one-pass `trArgs`); B7, B8 un-skipped. fluxy_i18n 57, none skipped; every package, root and both examples pass; BOOFI (97) and Hesabak (1,371) copies analyze clean and pass.

### Phase 3 (2026-11-19): switch, direction, device locale

- Direction (D2): `FluxyLocales` keeps the app's rule (`fixedDirection` / `directionFor`), `Fluxy.textDirection` reads it (reactive on the locale; left-to-right without a rule), `Fluxy.setTextDirectionRule` sets it, `resetLocales` clears it. `FluxyApp` / `FluxyCupertinoApp` gain `directionFor:` next to `textDirection:` (both through `ConfigData`); `FluxyRoot` applies them at mount and on every rebuilt app. The root `Directionality` is `FluxyRootDirection` (an `Obx` over `Fluxy.textDirection`), so `fa` / `ar` no longer flip the app by themselves. `rtlLanguages` is data only now, with `ckb`, `dv`, `sd`, `ug`, `yi` added.
- The Material / Cupertino app is built in an `Obx`: `Fluxy.locale = x` alone updates the locale Flutter's `Localizations` get (`fluxyAppLocale`), with a debug log once per locale whose language is not in `supportedLocales` (unless the app passes a resolution callback).
- `Fluxy.forceAppUpdate()` (used by `updateLocale(rebuildAll: true)` and a rebuilt app's new locale) marks every element for a rebuild and completes after that frame, instead of `performReassemble` (no `State.reassemble`, no forced layout / paint of every render object; waits for the end of a frame when called during one). A rough timing on a 3,000-row screen in a debug widget test: 339 ms with reassemble, 139 ms marking (2.4x); release numbers not measured.
- A device-following app (no `locale:`, or `followDeviceLocale: true` without one) starts in the device language unless `Fluxy.locale` was set before `runApp` (B3).
- Tests: `locale_wiring_test.dart` (13: no rule = left-to-right for Persian and Arabic, `directionFor` following `Fluxy.locale`, `textDirection` winning, a rebuilt app's new rule, an `Obx` over `Fluxy.textDirection`, the Cupertino app, reset, Material locale following `Fluxy.locale`, the warning once / not with a callback, no `reassemble` on `updateLocale`, device language at start, a locale set before `runApp` kept); B3 and D2 / B12 un-skipped; no skipped tests left in either package. Every package (fluxy_nav 265), root and both examples pass; BOOFI (97) and Hesabak (1,371) copies analyze clean and pass.

### Phase 4 (2026-11-19): missing keys, check tool, digits

- `Fluxy.onMissingTranslation` / `FluxyApp(onMissingTranslation:)` (and `FluxyCupertinoApp`, through `ConfigData`): called when `.tr` (so `trParams`, `trCount`…) finds a key in no dictionary, once per key until the locale or the dictionaries change, with the key and the locale; a key the fallback has is not missing. Called in every mode when set (not debug-only as first planned): the app wraps it in `kDebugMode` if it wants. No cost when unset. `resetLocales` clears it.
- `lib/src/digits.dart` (D5): `'12:30'.localDigits([locale])` / `n.localDigits([locale])` write Western digits in the language's CLDR default digits (Persian / `persian` / Pashto ۰-۹, Arabic and Sorani ٠-٩ except the Maghreb, Marathi / Nepali Devanagari, Bengali, Burmese; English, Urdu, Hindi and the rest unchanged), default `Fluxy.locale` (reactive); `'۱۲۳'.westernDigits` reads every native digit set back for parsing. `nativeZeroFor(locale)` exported. NestCut's `localDigits()` (14 calls) and `mainCTRL.language` checks can move to it.
- `tool/i18n_check.dart` (D4) with `tool/src/dart_tokens.dart` (a small tokenizer, no analyzer dependency, like the codemod) and `tool/src/i18n_check_command.dart`: keys used (literals before `.tr` members, `trCount` forms, `trPlural` plural keys; interpolations and variables counted as not checked) against dictionaries (a `Translations` `keys` getter, `addTranslations` / `appendTranslations`, `translationsKeys:`, following constants, spreads and constructor / `Map.of` calls). `--locale`, `--ignore`, `--dir`, `--no-unused`, `--fail`. On the apps: BOOFI en_US 10 missing / 279 unused (spot-checked: real); Hesabak en_US 2 missing; NestCut none missing, 167 unused. `tool/README.md` section.
- Tests: fluxy_i18n `digits_missing_test.dart` (10), fluxy_nav one more wiring test (`FluxyApp(onMissingTranslation:)`), tool `i18n_check_test.dart` (6). fluxy_i18n 67, fluxy_nav 266, tool 69; every package, root and both examples pass; BOOFI (97) and Hesabak (1,371) copies analyze clean and pass.
