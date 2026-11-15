# Fluxy

Fluxy is a fork of [GetX](https://github.com/jonataslaw/getx) (from commit `a294d2f`), split into separate packages so each project can depend on only what it needs.

| Package | What it holds | Depends on |
|---|---|---|
| [`fluxy_core`](packages/fluxy_core) | `Get` singleton, logging, engine, `Equality` | — |
| [`fluxy_state`](packages/fluxy_state) | Rx, `Obx`, controllers, workers, DI | core |
| [`fluxy_i18n`](packages/fluxy_i18n) | `Translations`, `.tr`, locale state | core, state |
| [`fluxy_utils`](packages/fluxy_utils) | `GetPlatform`, validators, extensions, queue | core |
| [`fluxy_nav`](packages/fluxy_nav) | router, `Get.to/back`, dialogs, sheets, snackbars | core, state, i18n, utils |
| [`fluxy_ui`](packages/fluxy_ui) | responsive views, `hp`/`wp`, animations | core, state, utils |

The root package (still named `get`) re-exports all of them, so `import 'package:get/get.dart'` keeps working.

## Using it

Everything:

```yaml
get:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v0.4.0
```

Only one package (for example state management):

```yaml
fluxy_state:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v0.4.0
    path: packages/fluxy_state
```

## Changes from upstream

- v0.1.0: no per-build `HeroController` in `GetNavigator` (heroes flew twice); `GetHeroScope` for nested or scope-less navigators.
- v0.2.0: `get_connect` (HTTP / sockets) removed.
- v0.3.0: split into packages. `Get.asap` and `Equality` moved to core; `RouterReportManager` moved to state; responsive views moved to ui; `hp`/`wp` no longer need navigation.
- v0.4.0 (fluxy_state, ideas from [Sint](https://github.com/Open-Neom/sint), MIT):
  - `Obx` / `GetX` keep only the subscriptions their last build read; an Rx no longer read stops rebuilding them.
  - `Get.batch(() { ... })`: each changed Rx notifies once, with its final value, when the outermost batch ends.
  - `rx.peek` and `Get.untrack(() => ...)` read without subscribing. Setters, `toggle()`, `+` / `-` and collection writes use `peek`, so writing inside a build doesn't subscribe to the written Rx.
  - `RxList` / `RxMap` / `RxSet` bulk operations (`insert`, `removeAt`, `removeRange`, `replaceRange`, `setAll`, `fillRange`, `addAll`, `updateAll`, `addEntries`, `assignAll` ...) notify once per call; `addAll` / `insertAll` with the collection itself no longer throws.
  - DI keys are the `Type` (or a `(Type, tag)` record) instead of `type.toString()`: two classes with the same name no longer collide, and neither do `Foo` + tag `Bar` and `FooBar`. The `key:` parameters of `delete`, `reload` and `markAsDirty` are now `Object?`.
  - Fixed `RxnDouble -` (it added).
- Unreleased (fluxy_i18n, ideas from Sint):
  - `.tr` is reactive: an `Obx` showing translated text rebuilds when the locale or dictionaries change. `Get.translationVersion` exposes the signal. fluxy_i18n now depends on fluxy_state for this.
  - `.tr` looks in a cached list of dictionaries for the current locale (same lookup order as before), rebuilt only after a change, instead of scanning all dictionaries on a miss.
  - `appendTranslations` copies instead of modifying, so it works after `const` dictionaries; `addTranslations` stores copies too.
  - `.trParams` makes one pass: a placeholder only matches a whole name (`@admin` no longer eats `@admin_email`), inserted values are not replaced again, names may contain `-`.
  - `Get.updateLocale(l, rebuildAll: false)` skips the full-app reassemble. The default stays `true`: widgets that read `.tr` in a plain `build` need it.
