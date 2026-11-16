# Plan: from `get` to Fluxy names

Status: decided 2026-11-17. Phase 0 done (codemod in `tool/`, `dart fix` checked). Phases 1 and 2 committed on main (unreleased; v0.8.0 and v0.9.0 still to tag). Decisions are listed under "Decisions" at the end.

## Goal

Fluxy stops presenting itself as GetX: its own package name, its own type names, no `Get`-branded API. That happens without a breaking day for the BOOFI app: every step keeps the old names working (deprecated) until the app has moved, and the move itself is scripted.

Not a goal: renaming the idioms that are short and not branded. `.obs`, `Rx…`, `Obx`, `ObxValue`, `Computed`, `effect`, `RxFuture`, `RxCommand`, `StateMixin` and `.tr` stay as they are (about 2,300 uses in the app, little to gain).

## Where things stand

The app (`boofi/lib`, 87 imports of `package:get/get.dart`, plus 2 commented out in `main copy.dart` files) uses:

| Area | Uses | Ready to rename? |
|---|---|---|
| `Get.` navigation / dialogs / snackbars (`back` 133, `closeAllDialogs` 80, `defaultDialog` 62, `dialog` 42, `to` / `offAll` 16, `bottomSheet` 6, …) | ~390 | Phase 3 (`Get.` → `Fluxy.`, with the nav rework) |
| `Get.put` | 20 | Phase 3 (`Fluxy.put`, typed DI handles) |
| `.tr` | 1,684 | Stays |
| `.obs` / `Rx…` / `Obx` | ~640 | Stay |
| `GetxController` | 20 | Phase 2 |
| `StateMixin` | 20 | Stays |
| `GetPage` / `GetMaterialApp` / `GetDelegate` / `GetNavigator` | 28 | Phase 3 (with the nav rework) |

Library side: 26 `Get…` public types in fluxy_nav, 20 in fluxy_state (plus 6 `Obx…`, kept), 9 in fluxy_utils, 5 in fluxy_ui, `GetInterface` in fluxy_core. The state layer is the mature part (184 tests, fastest in 8 of 12 benchmark scenarios); navigation is still mostly upstream code, and fluxy_core / fluxy_i18n have no tests.

## How the migration is done

- **Deprecated aliases.** Every renamed type keeps its old name as `@Deprecated('Use X') typedef Old = New;` (and forwarding members for renamed methods), exported from the same library, until phase 4 removes them. Nothing breaks on upgrade; the analyzer lists what is left to move.
- **`dart fix` for type renames, the codemod for everything else.** Both checked in phase 0 on a copy of the app (Flutter 3.50 / Dart 3.14):
  - A `lib/fix_data.yaml` with `rename` transforms works through the deprecated typedef aliases (typedef → class is fine): `extends`, type arguments, constructors through the alias, `is`, bounds and `show` lists, and the `GetStatus` subclasses are left alone. The element's `uris` must list the library the app imports, `package:get/get.dart` (and, from phase 1 on, `package:fluxy/fluxy.dart` too); listing only the declaring package finds nothing. It lives in the root package. Moving `Get.` facade members to other classes with `dart fix` is untested; the codemod covers that.
  - `tool/migrate.dart` applies `tool/renames.txt` (`Old New` per line) to a project: whole words, member accesses (`Get.back Nav.back`, `Get.back( Nav.back(` for calls only) and directive URIs (exact or prefix), in one pass, skipping comments and strings. On the app copy it gave the same result as `dart fix` for the two type renames (20 changes in 19 files, analyze clean apart from the 2 Firebase infos, 97 tests pass); dry runs: the import rewrite 87 changes, three facade calls (`back`, `closeAllDialogs`, `defaultDialog`) 266 changes in 44 files. See `tool/README.md`.
  - Formatting: 155 of the app's 170 Dart files are not `dart format` clean, so the codemod formats a changed file only if it was clean before (`--format auto`, default), to keep rename diffs to the renamed lines.
  - The app has two branches in worktrees (`boofi/.claude/worktrees`) that import `get`: re-run the codemod on them when they merge (a second run changes nothing).
- **One release per phase**, each with release notes listing every rename, and the app bumped and tested as usual.

## Naming rules (decided 2026-11-17)

1. Every `Get` prefix becomes `Fluxy` (`GetxController` → `FluxyController`, `GetStatus` → `FluxyStatus`, `GetQueue` → `FluxyQueue`). One rule, nothing to look up.
2. The `Get` facade object becomes one `Fluxy` object (`Get.back()` → `Fluxy.back()`), not split by job.
3. Names that are not `Get`-branded stay (`Obx`, `Rx…`, `StateMixin`, the `GetStatus` subclasses `LoadingStatus` / `SuccessStatus` / …).
4. Checked against the app: none of the names below is used there today.

## Phases

### Phase 0: spike (no release) — done

- `dart fix` checked with two aliases (`GetxController` → `FluxController`, `GetStatus` → `AsyncStatus`) on a copy of the app: works, see above. The spike's aliases were not kept.
- `tool/migrate.dart` written (44 tests, `cd tool && dart test`) and run on a copy of the app.
- Still open: the questions at the end.

### Phase 1: package name (v0.8.0) — committed 2026-11-17

- Root package `get` becomes `fluxy`; `lib/get.dart` becomes `lib/fluxy.dart` (`import 'package:fluxy/fluxy.dart';`). The split libraries (`instance_manager.dart`, `route_manager.dart`, `state_manager.dart`, `utils.dart`) move along.
- No compatibility package: the app is the only consumer and switches in the same release. App migration: pubspec `get:` → `fluxy:` and the import rewrite (87 files, one codemod line: `package:get/ package:fluxy/`).
- Also: examples, README, FLUXY.md, description in pubspec. The benchmark app `apps/fluxy` is left on `get:` (it no longer resolves) and is updated in phase 4.
- Internal folders (`get_core`, `get_rx`, `get_navigation`, …) are not renamed here: no API effect, and it costs history readability. Done once, in phase 4, if at all.

### Phase 2: state, UI and utils types (v0.9.0) — committed 2026-11-17

| Old | New |
|---|---|
| `GetxController` | `FluxyController` |
| `GetxService` / `GetxServiceMixin` | `FluxyService` / `FluxyServiceMixin` |
| `GetLifeCycleMixin` | `FluxyLifeCycleMixin` |
| `GetView` / `GetWidget` | `FluxyView` / `FluxyWidget` |
| `GetBuilder` | `FluxyBuilder` |
| `GetX<T>` (widget) | `FluxyX<T>` |
| `GetStatus` | `FluxyStatus` (subclasses `LoadingStatus`, `SuccessStatus`, `ErrorStatus`, `EmptyStatus` keep their names) |
| `GetListenable` | `FluxyListenable` |
| `GetNotifier` | `FluxyNotifier` |
| `GetStateUpdate` | `FluxyStateUpdate` |
| `GetTickerProviderStateMixin` / `GetSingleTickerProviderStateMixin` | `FluxyTickerProviderStateMixin` / `FluxySingleTickerProviderStateMixin` |
| `GetResponsiveView` / `GetResponsiveWidget` / `GetResponsiveMixin` | `FluxyResponsiveView` / `FluxyResponsiveWidget` / `FluxyResponsiveMixin` |
| `GetAnimatedBuilder` | `FluxyAnimatedBuilder` |
| `GetPlatform` | `FluxyPlatform` |
| `GetUtils` (+ `GetStringUtils`, `GetNumUtils`, `GetDurationUtils`, `GetDynamicUtils`) | `FluxyUtils` (+ `FluxyStringUtils`, …) |
| `GetQueue` / `GetQueueCancelledException` | `FluxyQueue` / `FluxyQueueCancelledException` |
| `GetMicrotask` | `FluxyMicrotask` |
| also: `GetControllerBuilder`, `GetXControllerBuilder`, `GetXState`, `GetAnimatedBuilderState`, `GetReactiveExt`, and the unexported `GetWidgetCache` / `GetWidgetCacheElement` / `GetStateUpdate` | same names with `Fluxy` (the unexported ones get no alias) |

- `Get.batch(...)` becomes `Fluxy.batch(...)` with the facade in phase 3.
- Done as: the codemod with the phase 2 pairs of `tool/renames.txt` over `packages/`, root `test/` and the examples, plus old names in comments; deprecated aliases in one `lib/deprecated_names.dart` per package (fluxy_state, fluxy_utils, fluxy_ui); extensions (`GetStringUtils`, …) have no alias, and the app never names them. On a copy of the app, old names compile through the aliases (21 deprecation infos), and `dart fix --apply` and the codemod give identical results (21 renames in 20 files, 97 tests pass).
- Ship `lib/fix_data.yaml` with every type rename (uris: `package:fluxy/fluxy.dart`, the split libraries and the package libraries), so `dart fix --apply` works as well as the codemod.
- App impact: 20 `GetxController` lines; the rest is not used by the app.
- The full list of `Get…` public types is checked against this table before the release (26 in fluxy_nav, 20 in fluxy_state, 9 in fluxy_utils, 5 in fluxy_ui, `GetInterface` in fluxy_core); anything missed follows rule 1.

### Phase 3: navigation, dialogs and DI (v1.0.0)

This one is an API change, not a rename, and gets its own short spec first. Direction:

- The `Get` facade (navigation, dialogs, snackbars, bottom sheets, DI, screen size, theme, locale) becomes one `Fluxy` object: `Fluxy.back()`, `Fluxy.to(...)`, `Fluxy.dialog(...)`, `Fluxy.put(...)`. `GetInterface` becomes `FluxyInterface`. The spec decides what else changes on the way (nav rework, members that go).
- DI moves to the typed handles already on the roadmap (scoped, ref-counted), with `Fluxy.put / find / lazyPut / delete` kept.
- Navigation types: `GetMaterialApp` / `GetCupertinoApp` → `FluxyApp` / `FluxyCupertinoApp` (with `.router`), `GetPage` → `FluxyPage`, `GetMiddleware` → `FluxyMiddleware`, `GetDelegate` → `FluxyDelegate`, `GetInformationParser` → `FluxyInformationParser`, `GetNavigator` → `FluxyNavigator`, `GetObserver` → `FluxyObserver`, `GetRouterOutlet` → `FluxyRouterOutlet`, `GetSnackBar` → `FluxySnackBar`, `GetHeroScope` → `FluxyHeroScope`, `GetPageRoute` / `GetDialogRoute` / `GetModalBottomSheetRoute` → `Fluxy…Route`, `GetRoot` → `FluxyRoot`.
- Done together with the open nav work (static-first route matching, splitting `extension_navigation.dart` and `get_router_delegate.dart`), so the app migrates navigation once.
- The `Get` object stays, deprecated (`@Deprecated('Use Fluxy') final Get = Fluxy;`-style). App impact: ~390 `Get.` navigation / dialog calls and 20 `Get.put`, all through the codemod (one line: `Get Fluxy` as a member-access rename).
- Tests for fluxy_core and fluxy_i18n come before this phase, so the rename is not the first time those paths are tested.

### Phase 4: remove the old names (v1.1.0)

- Delete the deprecated aliases (`lib/deprecated_names.dart` in fluxy_state, fluxy_utils, fluxy_ui), the deprecated `Get` object and the transforms in `lib/fix_data.yaml`.
- Optionally move the internal `get_*` folders to `src/`.
- Benchmark: `apps/fluxy` moves to `fluxy:` and the new names, and the README's reason for one app per library is updated (GetX 4 and 5 are still both `get`).
- Final docs: README / FLUXY.md written as Fluxy, with a "coming from GetX" table generated from `tool/renames.txt`.
- The GetX `LICENSE` notice (MIT) stays, with Fluxy's copyright added.

## Risks

- **Deprecation noise.** Between a release and the app's codemod run, the app's analyzer lists every old name. Run the codemod in the same change as the version bump.
- **History.** Renames touch many lines. Keep each phase's rename in its own commit (no other changes), so `git log -S` and blame stay usable; never `dart format` whole upstream files.
- **Upstream.** After phase 2, pulling fixes from jonataslaw/getx becomes manual. Fluxy has diverged far enough that this is already mostly true.
- **Benchmark.** Not updated until phase 4: `apps/fluxy` does not build from v0.8.0 to then. `apps/getx4` and `apps/getx5` keep depending on packages named `get`.

## Decisions (2026-11-17)

1. Prefix: `Fluxy` everywhere a `Get` prefix was (not `Flux`, no plain names).
2. Facade: one `Fluxy.` object replacing `Get.`, not split by job.
3. No `get_compat`: the app switches package in the phase 1 release.
4. Versions step by 0.1: v0.8.0 package, v0.9.0 types, v1.0.0 facade + nav, v1.1.0 removes the old names.
