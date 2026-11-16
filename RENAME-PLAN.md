# Plan: from `get` to Fluxy names

Status: draft, 2026-11-16, after v0.7.3. Phase 0 done (codemod in `tool/`, `dart fix` checked); nothing renamed yet. Open questions below are still to decide.

## Goal

Fluxy stops presenting itself as GetX: its own package name, its own type names, no `Get`-branded API. That happens without a breaking day for the BOOFI app: every step keeps the old names working (deprecated) until the app has moved, and the move itself is scripted.

Not a goal: renaming the idioms that are short and not branded. `.obs`, `Rx…`, `Obx`, `ObxValue`, `Computed`, `effect`, `RxFuture`, `RxCommand`, `StateMixin` and `.tr` stay as they are (about 2,300 uses in the app, little to gain).

## Where things stand

The app (`boofi/lib`, 87 imports of `package:get/get.dart`, plus 2 commented out in `main copy.dart` files) uses:

| Area | Uses | Ready to rename? |
|---|---|---|
| `Get.` navigation / dialogs / snackbars (`back` 133, `closeAllDialogs` 80, `defaultDialog` 62, `dialog` 42, `to` / `offAll` 16, `bottomSheet` 6, …) | ~390 | Not yet: the facade should be split, not just renamed (phase 3) |
| `Get.put` | 20 | With typed DI handles (phase 3) |
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

## Naming rules (to confirm)

1. No prefix where a plain name is clear and does not clash with Flutter or the app (`AsyncStatus`, `ResponsiveView`, `TaskQueue`).
2. `Flux` prefix for Fluxy building blocks that would otherwise clash or read as generic (`FluxController`, `FluxView`, `FluxPage`).
3. `Fluxy` only for brand-level entry points: the package, the app widget (`FluxyApp`).
4. Checked against the app: none of the proposed names below is used there today. `Dialogs` is (11 uses), so it is not a candidate for a facade name.

## Phases

### Phase 0: spike (no release) — done

- `dart fix` checked with two aliases (`GetxController` → `FluxController`, `GetStatus` → `AsyncStatus`) on a copy of the app: works, see above. The spike's aliases were not kept.
- `tool/migrate.dart` written (44 tests, `cd tool && dart test`) and run on a copy of the app.
- Still open: the questions at the end.

### Phase 1: package name (v0.8.0)

- Root package `get` becomes `fluxy`; `lib/get.dart` becomes `lib/fluxy.dart` (`import 'package:fluxy/fluxy.dart';`). The split libraries (`instance_manager.dart`, `route_manager.dart`, `state_manager.dart`, `utils.dart`) move along.
- A compatibility package `packages/get_compat`, named `get`, re-exports `fluxy`. Until the app switches, it can point its `get:` dependency at that path (`path: packages/get_compat`) and nothing changes for it.
- App migration: pubspec `get:` → `fluxy:` and the import rewrite (87 files, one codemod line: `package:get/ package:fluxy/`).
- Also: benchmark app `apps/fluxy` depends on `fluxy:`, CI workflow, README, FLUXY.md, description in pubspec.
- Internal folders (`get_core`, `get_rx`, `get_navigation`, …) are not renamed here: no API effect, and it costs history readability. Done once, in phase 4, if at all.

### Phase 2: state, UI and utils types (v0.9.0)

| Old | New |
|---|---|
| `GetxController` | `FluxController` |
| `GetxService` / `GetxServiceMixin` | `FluxService` / `FluxServiceMixin` |
| `GetLifeCycleMixin` | `FluxLifecycleMixin` |
| `GetView` / `GetWidget` | `FluxView` / `FluxWidget` |
| `GetBuilder` | `FluxBuilder` |
| `GetX<T>` (widget) | `RxControllerBuilder<T>` |
| `GetStatus` | `AsyncStatus` (subclasses `LoadingStatus`, `SuccessStatus`, `ErrorStatus`, `EmptyStatus` keep their names) |
| `GetListenable` | `RxListenable` |
| `GetNotifier` | `FluxNotifier` |
| `GetStateUpdate` | `StateUpdate` |
| `GetTickerProviderStateMixin` / `GetSingleTickerProviderStateMixin` | `FluxTickerProviderStateMixin` / `FluxSingleTickerProviderStateMixin` |
| `GetResponsiveView` / `GetResponsiveWidget` / `GetResponsiveMixin` | `ResponsiveView` / `ResponsiveWidget` / `ResponsiveMixin` |
| `GetAnimatedBuilder` | `FluxAnimatedBuilder` |
| `GetPlatform` | `FluxPlatform` |
| `GetUtils` (+ `GetStringUtils`, `GetNumUtils`, `GetDurationUtils`, `GetDynamicUtils`) | `FluxUtils` (+ `…Utils` extensions without the prefix) |
| `GetQueue` / `GetQueueCancelledException` | `TaskQueue` / `TaskQueueCancelledException` |
| `GetMicrotask` | `FluxMicrotask` |

- `Get.batch(...)` also becomes a top-level `batch(...)` (the facade method stays, forwarding).
- Ship a `fix_data.yaml` with every type rename (uris: `package:fluxy/fluxy.dart`, and `package:get/get.dart` while that path exists), so `dart fix --apply` works as well as the codemod.
- App impact: 20 `GetxController` lines; the rest is not used by the app.

### Phase 3: navigation, dialogs and DI (v0.10.0)

This one is an API change, not a rename, and gets its own short spec first. Direction:

- The `Get` facade (one object doing navigation, dialogs, snackbars, bottom sheets, DI, screen size, theme, locale) is split by job, for example `Nav.back()`, `Nav.to(...)`, `Nav.offAll(...)`, `Overlays.dialog(...)` / `Overlays.closeAll()`, `Overlays.snackbar(...)`, `Screen.size`, `Themes.changeMode(...)`. Final names in the spec; each must not clash with Flutter or the app.
- DI moves to the typed handles already on the roadmap (`final cart = Inject.put(CartController())`-style, scoped, ref-counted), with `Get.put / find / lazyPut / delete` forwarding.
- Navigation types: `GetMaterialApp` / `GetCupertinoApp` → `FluxyApp` / `FluxyCupertinoApp` (with `.router`), `GetPage` → `FluxPage`, `GetMiddleware` → `FluxMiddleware`, `GetDelegate` → `FluxRouterDelegate`, `GetInformationParser` → `FluxRouteInformationParser`, `GetNavigator` → `FluxNavigator`, `GetObserver` → `FluxRouteObserver`, `GetRouterOutlet` → `FluxRouterOutlet`, `GetSnackBar` → `FluxSnackBar`, `GetHeroScope` → `FluxHeroScope`, `GetPageRoute` / `GetDialogRoute` / `GetModalBottomSheetRoute` → `Flux…Route`, `GetRoot` → `FluxyRoot`.
- Done together with the open nav work (static-first route matching, splitting `extension_navigation.dart` and `get_router_delegate.dart`), so the app migrates navigation once.
- The `Get` object stays, deprecated, forwarding to the new homes. App impact: ~390 `Get.` navigation / dialog calls and 20 `Get.put`, all through the codemod (the map handles `Get.back(` → `Nav.back(` style rewrites).
- Tests for fluxy_core and fluxy_i18n come before this phase, so the rename is not the first time those paths are tested.

### Phase 4: remove the old names (v1.0.0)

- Delete the deprecated aliases, the forwarding `Get` facade and `get_compat`.
- Optionally move the internal `get_*` folders to `src/`.
- Final docs: README / FLUXY.md written as Fluxy, with a "coming from GetX" table generated from `tool/renames.txt`.
- The GetX `LICENSE` notice (MIT) stays, with Fluxy's copyright added.

## Risks

- **Deprecation noise.** Between a release and the app's codemod run, the app's analyzer lists every old name. Run the codemod in the same change as the version bump.
- **History.** Renames touch many lines. Keep each phase's rename in its own commit (no other changes), so `git log -S` and blame stay usable; never `dart format` whole upstream files.
- **Upstream.** After phase 2, pulling fixes from jonataslaw/getx becomes manual. Fluxy has diverged far enough that this is already mostly true.
- **Benchmark.** `apps/getx4` and `apps/getx5` keep depending on packages named `get`; only `apps/fluxy` changes.

## Open questions

Phase 0's recommendation (input, not a decision): `Flux` / `Fluxy` as proposed; split the facade (the codemod moved 266 calls in one pass, so a split costs about the same as one `Fluxy.` object); skip `get_compat` and switch the app in the phase 1 release (one consumer, one codemod line); keep the phased versions.

1. Prefix: `Flux` for building blocks and `Fluxy` for entry points (proposed), `Fluxy` everywhere, or no prefix where possible?
2. Phase 3 facade names: `Nav` / `Overlays` / `Screen` / `Themes` / `Inject`, or one `Fluxy.` facade (simpler, still one object)?
3. Keep `get_compat` for a few releases, or let the app switch package in the same release as phase 1?
4. Version numbers: as above (0.8 / 0.9 / 0.10 / 1.0), or a single 1.0 for everything at once?
