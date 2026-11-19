# Fluxy tools

## `migrate.dart`: rename codemod

Applies a rename map to the Dart files of a project (an app moving to new Fluxy names), so a rename release and the app's update can land together.

```bash
dart run tool/migrate.dart <project-dir> [--map tool/renames.txt] [--dry-run] [--keep-refresh] [--material-ui] [--format auto|always|never]
```

It prints one `path: count` line per changed file, a **Review** list (`path:line: what to check`) and a total. Review the diff and the list, then run the project's `flutter analyze` and `flutter test`.

### Clean-ups for apps coming from GetX

Before the renames, each file gets these clean-ups (found moving apps):

- **Redundant `refresh()`** (dropped). In Fluxy `refresh()` is `@protected`, and most GetX calls follow a write that already notifies. A `x.refresh();` statement is dropped when, in the same block, it follows a write to the same `x` that always notifies: `x[…] = v` (or `+=`, `??=` …), `x.add` / `addAll` / `insert` / `remove` / `removeAt` / `removeWhere` / `retainWhere` / `clear` / `sort` / `update` / `updateAll` …. Up to 5 statements may sit in between if they read `x` and write nothing, such as saving it: `await db.write(key, x.toList());`. Every other `refresh()` statement is listed for review (most are an in-place edit, where `x[i] = item` is the Fluxy way, or a "nudge" after a reload). `.value =`, `assignAll`, `putIfAbsent` and `addIf` don't count as writes, because they can skip notifying (same value, same map, condition false). `--keep-refresh` lists the redundant ones instead of dropping them. On one real app's GetX code: 38 of 99 dropped, 61 listed.
- **Deep `package:get/<path>` imports** (`get_utils/src/…`) become `package:get/get.dart` (then `package:fluxy/fluxy.dart`), since Fluxy has no such files; the import is dropped when the file already imports the whole library. `state_manager.dart`, `route_manager.dart`, `instance_manager.dart` and `utils.dart` exist in Fluxy and are kept.
- **Old names in strings** (listed, not changed): a test that greps the app's source (`contains('Get.put(UsersController())')`) or a log line. Plain `Get` only counts before a dot.

`--material-ui` also rewrites `package:flutter/material.dart` to `package:material_ui/material_ui.dart` and `package:flutter/cupertino.dart` to `package:cupertino_ui/cupertino_ui.dart`. Add both packages to `pubspec.yaml`, then follow [Moving an app that uses flutter/material](../README.md#moving-an-app-that-uses-fluttermaterial) for packages still on `flutter/material`.

### The map

`tool/renames.txt`, one `Old New` pair per line, `#` starts a comment:

| Pair | Matches |
|---|---|
| `GetxController FluxController` | the whole word, in code |
| `Get.back Nav.back` | the member access (call or tear-off); spaces and line breaks around the dot allowed; not after another `.` (`foo.Get.back`) or on a cascade |
| `Get.back( Nav.back(` | calls only (`Get.back()`, `Get.to<T>(...)`) |
| `package:get/get.dart package:fluxy/fluxy.dart` | that URI in `import` / `export` / `part` directives (conditional imports included) |
| `package:get/ package:fluxy/` | every directive URI with that prefix |

Pairs are applied in one pass: a new name is never renamed again by another pair, and the longest member pair wins.

### What it skips

- Comments (line, doc, nested block) and string literals; names inside `${...}` and `$name` interpolation are code and are renamed.
- Hidden folders (`.dart_tool`, `.git`, `ios/.symlinks`, ...), `build`, `node_modules`, `Pods`, `actions-runner` (a self-hosted GitHub runner's checkout), non-Dart files, and `deprecated_names.dart` files (Fluxy's deprecated aliases, which declare the old names on purpose).

It does not resolve names: a local declaration that happens to use an old name is renamed too, and the project's analyzer is the check.

### Formatting

With `--format auto` (default) it runs `dart format` on a changed file only if the file was `dart format` clean before the rewrite, so code that was never formatted does not get a whole-file reformat in the rename diff. `always` formats every changed file, `never` none.

### Tests

```bash
cd tool && dart pub get && dart test
```

## `dart fix` data

Checked in phase 0 (Flutter 3.50 / Dart 3.14): a `lib/fix_data.yaml` with `rename` transforms for a deprecated typedef alias (`typedef GetxController = FluxController`) does work with `dart fix`, if the element's `uris` list the library the app imports (`package:get/get.dart`), not only the package that declares it. The analyzer reads `fix_data.yaml` from every package in the app's dependency graph. The codemod stays the main tool: it also handles URIs and the facade member moves.

The root package ships `lib/fix_data.yaml` with the type renames and `Get` → `Fluxy`, so after the pubspec and import switch `dart fix --apply` gives the same result as the codemod (checked on a copy of the app, with and without the old names still declared: identical files). `dart fix` has no data-driven fix for an enum value that is gone (`undefined_enum_constant`; checked on Dart 3.14 with `constant`/`field`/`getter` + `inEnum`/`inClass`), so GetX 4's upper-case values (`SnackPosition.BOTTOM` …) are renamed by the codemod only (pairs at the end of `renames.txt`).

## `i18n_check.dart`: missing and unused translation keys

Compares the keys an app translates with its dictionaries.

```bash
dart run tool/i18n_check.dart <project-dir> [--locale en_US] [--ignore <regex>] [--dir lib] [--no-unused] [--fail]
```

For each dictionary (locale) it prints how many keys it holds, the keys used in code that it lacks (with `file:line`, the first three places) and the keys no code uses. `--fail` exits with 1 when a key is missing, for CI.

- **Keys used:** string literals (adjacent ones joined) before `.tr`, `.trParams`, `.trArgs`, `.trCount` (any of its forms `key.zero` … `key.other` counts), `.trPlural` / `.trPluralParams` (and their plural-key argument). `.tr` on an interpolation (`'Total: $n'.tr`) or a variable is counted as "not checked".
- **Dictionaries:** the map a `Translations` subclass returns from `keys`, the argument of `addTranslations` / `appendTranslations`, and `translationsKeys:`. Values may be map literals, spreads, top-level or static constants, or a constructor / `Map.of` call whose first argument is one of those (e.g. `EnglishTranslations(kEnglishDictionary)`).
- **Persian-as-key apps**: check only the other language (`--locale en_US`); template keys (`'مانده: {0}'`) look unused, so leave them out with `--ignore '\{\d\}'`.

On three real apps (2026-11-19) it found 0-10 missing keys each; unused counts run high (hundreds to thousands) where keys are used through variables and templates.

