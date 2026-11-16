# Fluxy tools

## `migrate.dart`: rename codemod

Applies a rename map to the Dart files of a project (an app moving to new Fluxy names), so a rename release and the app's update can land together.

```bash
dart run tool/migrate.dart <project-dir> [--map tool/renames.txt] [--dry-run] [--format auto|always|never]
```

It prints one `path: count` line per changed file and a total. Review the diff, then run the project's `flutter analyze` and `flutter test`.

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
- Hidden folders (`.dart_tool`, `.git`, `ios/.symlinks`, ...), `build`, `node_modules`, `Pods`, and non-Dart files.

It does not resolve names: a local declaration that happens to use an old name is renamed too, and the project's analyzer is the check.

### Formatting

With `--format auto` (default) it runs `dart format` on a changed file only if the file was `dart format` clean before the rewrite, so code that was never formatted does not get a whole-file reformat in the rename diff. `always` formats every changed file, `never` none.

### Tests

```bash
cd tool && dart pub get && dart test
```

## `dart fix` data

Checked in phase 0 (Flutter 3.50 / Dart 3.14): a `lib/fix_data.yaml` with `rename` transforms for a deprecated typedef alias (`typedef GetxController = FluxController`) does work with `dart fix`, if the element's `uris` list the library the app imports (`package:get/get.dart`), not only the package that declares it. The analyzer reads `fix_data.yaml` from every package in the app's dependency graph. The codemod stays the main tool: it also handles URIs and the facade member moves.
