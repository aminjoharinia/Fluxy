# Fluxy

Fluxy is a fork of [GetX](https://github.com/jonataslaw/getx) (from commit `a294d2f`), split into separate packages so each project can depend on only what it needs.

| Package | What it holds | Depends on |
|---|---|---|
| [`fluxy_core`](packages/fluxy_core) | `Get` singleton, logging, engine, `Equality` | — |
| [`fluxy_state`](packages/fluxy_state) | Rx, `Obx`, controllers, workers, DI | core |
| [`fluxy_i18n`](packages/fluxy_i18n) | `Translations`, `.tr`, locale state | core |
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
    ref: v0.3.0
```

Only one package (for example state management):

```yaml
fluxy_state:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v0.3.0
    path: packages/fluxy_state
```

## Changes from upstream

- v0.1.0: no per-build `HeroController` in `GetNavigator` (heroes flew twice); `GetHeroScope` for nested or scope-less navigators.
- v0.2.0: `get_connect` (HTTP / sockets) removed.
- v0.3.0: split into packages. `Get.asap` and `Equality` moved to core; `RouterReportManager` moved to state; responsive views moved to ui; `hp`/`wp` no longer need navigation.

Tests live in the root `test/` folder and run through the umbrella package. Run `flutter analyze` in each `packages/*` folder to check that no package reaches outside its listed dependencies.
