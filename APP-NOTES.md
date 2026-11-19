# Notes from the apps

What moving and running real apps on Fluxy shows: gaps, rough edges and ideas, kept here until they become a plan or a release. Each note says where it came from, what happened, and what Fluxy could do. Move a note to **Done** with its release when it lands; drop it if it turns out wrong.

Apps:

- **BOOFI**: `~/Workspace/BOOFI/Application/boofi`. On Fluxy since v0.1.0 (it came from GetX 5). Uses no `refresh()`: in-place edits go through the rx_edit helpers (`patch`, `setIn`, …).
- **Hesabak** (accounting): `~/Workspace/AnimooAPPs/accounting`. Moved from GetX 4.7.3 to Fluxy v1.5.0 on 2026-11-19 (branch `fluxy-migration`). About 99k lines. Each book is an untyped `RxList` / `RxMap` of maps, with large lists read inside `Obx`.
- **NestCut** (panel and block cutting optimizer): `~/Workspace/AnimooAPPs/nestingapp`. Still on GetX 4.7.3 (checked 2026-11-19, not moved yet). About 38k lines in 66 files: 43 files import `get`, 51 `Obx`, 4 controllers put in `main()` as `permanent`, 692 `.tr` and 123 `.trParams`, no `GetBuilder`, routes or bindings. Its whole `GetMaterialApp` is built inside an `Obx` (language, dark mode, colours, font).

## Open

### Migration (GetX 4 → Fluxy)

1. **Apps still on `package:flutter/material.dart` must move to `material_ui`** (Hesabak). Fluxy is built on `material_ui`, so `FluxyApp(theme:)`, `themeMode:` and friends take `material_ui` types. An app importing `flutter/material` gets about 50 `ThemeData` / `ThemeMode` type errors. Hesabak's fix: rewrite the 190 imports to `package:material_ui/material_ui.dart` (and `flutter/cupertino` to `cupertino_ui`), add both packages to the pubspec, and then deal with the packages that still use `flutter/material` (persian_datetime_picker, printing, intl_phone_field, flutter_slidable). NestCut will need the same: 41 files import `flutter/material`, and it uses printing too:
   - Wrap the app in `MaterialUiCompatibilityBridge` (deprecated, but it is the official bridge) in `FluxyApp(builder:)`, so those widgets get the app's colours and fonts, dark mode included.
   - Keep their localizations as `flutter/material` delegates (`PersianMaterialLocalizations.delegate`, `legacy.DefaultMaterialLocalizations.delegate`), and add `material_ui`'s `GlobalMaterialLocalizations.delegate` / `cupertino_ui`'s `GlobalCupertinoLocalizations.delegate` for the app's own widgets.
   - Code that hands `MaterialLocalizations` to such a package (Hesabak's Jalali date picker passes it to `PersianDateUtils`) imports `MaterialLocalizations` from `flutter/material`.

   **Fluxy could:** add a "Moving an app on flutter/material" section to the README with this recipe; give the codemod an opt-in `--material-ui` pair set (the two import rewrites); and maybe `FluxyApp(legacyMaterialBridge: true)`, which wraps the bridge so apps don't write the deprecated name themselves.

3. **Deep `package:get/...` imports become `package:fluxy/...` paths that don't exist** (Hesabak: `get_utils/src/extensions/internacionalization.dart`). **Fluxy could:** have the codemod rewrite any `package:get/<path>` other than `get.dart` to `package:fluxy/fluxy.dart` (and drop the import when the file already has it), or at least list such imports.

4. **Most `refresh()` calls in GetX code are redundant** (Hesabak: 92 of 100). They follow a write that already notifies (`list[i] = x`, `add`, `removeWhere`, `assignAll`, `map[k] = v`, a `.value =` reload). In Fluxy `refresh()` is `@protected` on purpose, so each of them is an analyzer warning after the codemod. NestCut has only one, and it is not redundant: it is the in-place row case of note 7. So the codemod must drop only a `refresh()` that follows a notifying write, never all of them. **Fluxy could:** have the codemod (or a later lint) drop a `refresh()` statement that directly follows a notifying write on the same receiver, and list the others for review.

### State

5. **No public "notify without a value change" on `RxList` / `RxMap`** (Hesabak, 2 sites kept with `// ignore: invalid_use_of_protected_member`). `WarehouseService` refreshes `productsList` after a warehouse transfer because product cards and pickers show warehouse balances, which are computed from `warehouseTransfers`. `trigger` and `update(fn)` exist only on `Rx<T>`, and on `RxMap`, `update` is the `Map` method. BOOFI never needed this. **Options:** keep it protected and recommend reading both collections in the view (or in a `Computed` over both); or add an explicit, rarely needed `markChanged()` to collections. Decide when a second app needs it.

7. **Rows that are mutable objects edited in place** (Hesabak's `InvoiceItem`): `items[i] = item` (storing the same object back) notifies, and that is the public way to say "this row changed". It is easy to miss: Hesabak had `items.refresh()` after `item.finalPrice = …`, and NestCut has `savedManualLayouts.refresh()` after `layout.name = …` (`ProjectController.renameManual`). **Fluxy could:** document the idiom in fluxy_state's README next to `patch`. After an `await`, look the row up again by identity (`items.peek.indexWhere((e) => identical(e, item))`), since rows may have moved.

11. **Disposing a `FluxyApp` closes every dependency** (`FluxyRootState.onClose` → `Fluxy.resetInstance()`, carried over from GetX 5; GetX 4 kept them). Apps register their controllers in `main()` before `runApp` (Hesabak, and BOOFI's top-level `final X = Fluxy.put(...)`), so if the app widget is ever unmounted and mounted again (a boot gate swapping screens, a key change), those controllers are closed and gone while code still holds them. That is the B1 / B7 problem v1.4.0 fixed for routes. NestCut does the same (three `Get.put(..., permanent: true)` in `main()`); its app widget is never unmounted, so it is safe today, but `permanent` there reads as a promise Fluxy would break. Seen in Hesabak's tests: a page's dispose callback ran after the app was torn down and found no `ProductsController` (Hesabak now checks `isRegistered` there). **Decide (D1 follow-up):** keep registrations made outside the app when it is disposed (reset only what the app itself set up: translations, overlays, the delegate), and leave `Fluxy.reset()` to tests.

12. **The codemod skips string literals, so tests that grep the app's source still expect GetX names** (Hesabak: 7 assertions like `contains('Get.put(UsersController())')`). **Fluxy could:** have the codemod report string literals that contain a renamed name (without changing them).

13. **The secure storage packages depended on GetX itself** (Hesabak and NestCut). `get_secure_storage` 1.0.5 (NestCut) and `orca_secure_storage` up to v2.4.2 (our fork, Hesabak) depend on `get`, so Hesabak on Fluxy still resolves `get` and ships two state managers. **Fixed in Orca v2.5.0**, which no longer depends on `get` and keeps the 2.4.x file format (only `listenable`'s `ValueStorage` and the `queue` type changed; neither app uses them). **Apps:** Hesabak moves its pin from v2.4.2 to v2.5.0; NestCut switches from `get_secure_storage` to Orca v2.5.0 when it moves to Fluxy (Orca reads get_secure_storage 1.x files). After that, `get` should drop out of both lockfiles; check with `grep '^  get:' pubspec.lock`.

### Performance

9. **Whole-database scans inside `Obx`** (Hesabak: the home summary strip and `AccountLedger._statement` scan every factor list on each rebuild, including rebuilds caused by unrelated settings). This is app-side: wrap them in a `Computed` so they recompute only when a list they read changes. **Fluxy could:** show the pattern in fluxy_state's README ("a report over big lists").

## Done

- Unreleased (v1.6.0), from Hesabak and NestCut:
  - **2.** `Fluxy.backToFirst()`: closes dialogs and sheets, then pops to the first page (Hesabak's `popUntil(route.isFirst)` and NestCut's `Get.until((route) => route.isFirst)` sign-out). A "Coming from GetX" row.
  - **6.** The rx_edit map helpers are on `RxMap<K, V>`, so untyped `{}.obs` maps (Hesabak's groups) and int keys get `patch`, `addEntry` and the rest.
  - **8.** fluxy_state no longer exports its own `VoidCallback`; Hesabak's `hide VoidCallback` on orca_secure_storage can go.
  - **10.** `Fluxy.navigator` (and the top-level `navigator`) is the root `NavigatorState?`, null without an app. Hesabak's `rootNavigator` getter can become `Fluxy.navigator`. NestCut's `GlassToast.navigatorKey = Get.key` before `runApp` still needs a change when it moves (`Fluxy.key` throws until the app is mounted): set the key after the first frame, or have GlassToast take `() => Fluxy.navigator`.
  - **14.** A rebuilt `FluxyApp` takes a new `locale` / `fallbackLocale`, so NestCut's app-in-`Obx` no longer needs its extra `updateLocale` call (harmless to keep). Translations are still read once.

- v1.5.0, from Hesabak's widget tests (245 of its tests failed on v1.4.0 because of these two):
  - `FluxyApp` called `onReady` from a `Future`, a zero-length timer still pending when a test that pumps once ends ("A Timer is still pending even after the widget tree was disposed"). It now runs from a post-frame callback, as in GetX 4.
  - A rebuilt `FluxyApp` (a parent's build, or a test pumping another app in the same place) ignored its new `home` and themes: the config was read once in `initState`. Now a new `home` replaces the root page (updated in place when it is the same type), and a changed `theme` / `darkTheme` / `themeMode` is applied. A theme set with `Fluxy.changeTheme` / `changeThemeMode` stays until the app passes a different one.

- v1.5.0 (from Hesabak's list-in-`Obx` pattern): a repeated read of the same Rx in one run is one identity check; `RxList` / `RxMap` read methods read the collection once. 2.1–7× on 5,000-row reads.
