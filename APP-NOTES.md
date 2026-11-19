# Notes from the apps

What moving and running real apps on Fluxy shows: gaps, rough edges and ideas, kept here until they become a plan or a release. Each note says where it came from, what happened, and what Fluxy could do. Move a note to **Done** with its release when it lands; drop it if it turns out wrong.

Apps:

- **BOOFI**: `~/Workspace/BOOFI/Application/boofi`. On Fluxy since v0.1.0 (it came from GetX 5). Uses no `refresh()`: in-place edits go through the rx_edit helpers (`patch`, `setIn`, …).
- **Hesabak** (accounting): `~/Workspace/AnimooAPPs/accounting`. Moved from GetX 4.7.3 to Fluxy v1.5.0 on 2026-11-19 (branch `fluxy-migration`). About 99k lines. Each book is an untyped `RxList` / `RxMap` of maps, with large lists read inside `Obx`.
- **NestCut** (panel and block cutting optimizer): `~/Workspace/AnimooAPPs/nestingapp`. Still on GetX 4.7.3 (checked 2026-11-19, not moved yet). About 38k lines in 66 files: 43 files import `get`, 51 `Obx`, 4 controllers put in `main()` as `permanent`, 692 `.tr` and 123 `.trParams`, no `GetBuilder`, routes or bindings. Its whole `GetMaterialApp` is built inside an `Obx` (language, dark mode, colours, font).

## Open

### State

5. **No public "notify without a value change" on `RxList` / `RxMap`** (Hesabak, 2 sites kept with `// ignore: invalid_use_of_protected_member`). `WarehouseService` refreshes `productsList` after a warehouse transfer because product cards and pickers show warehouse balances, which are computed from `warehouseTransfers`. `trigger` and `update(fn)` exist only on `Rx<T>`, and on `RxMap`, `update` is the `Map` method. BOOFI never needed this. **Options:** keep it protected and recommend reading both collections in the view (or in a `Computed` over both); or add an explicit, rarely needed `markChanged()` to collections. Decide when a second app needs it.

### i18n

16. **Hesabak's English template lookup is lost on Fluxy** (found 2026-11-19 while planning [I18N-PLAN.md](I18N-PLAN.md), B1). `EnglishTranslations` is a `MapBase` that also answers interpolated lines through `{0}` templates; `addTranslations` copies it with `Map.of`, so only the exact keys survive and interpolated lines stay Persian in English. GetX 4 kept the map object. **Fix:** I18N-PLAN phase 1 (dictionaries stored as given).
17. **All three apps use a made-up `Locale('persian', 'US')`** so Flutter keeps the root left-to-right, then set direction per widget and keep their own `isEnglish` / direction getters. **Plan:** I18N-PLAN items 4-5 (direction policy, Material locale warning); each app then moves to `fa_IR`.

### For the apps

13. **The secure storage packages depended on GetX itself** (Hesabak and NestCut). `get_secure_storage` 1.0.5 (NestCut) and `orca_secure_storage` up to v2.4.2 (our fork, Hesabak) depend on `get`, so Hesabak on Fluxy still resolves `get` and ships two state managers. **Fixed in Orca v2.5.0**, which no longer depends on `get` and keeps the 2.4.x file format (only `listenable`'s `ValueStorage` and the `queue` type changed; neither app uses them). **Apps:** Hesabak moves its pin from v2.4.2 to v2.5.0; NestCut switches from `get_secure_storage` to Orca v2.5.0 when it moves to Fluxy (Orca reads get_secure_storage 1.x files). After that, `get` should drop out of both lockfiles; check with `grep '^  get:' pubspec.lock`.

## Done

- v1.6.1, from Hesabak on v1.6.0:
  - **15.** `Fluxy.changeTheme` / `changeThemeMode` called before a `FluxyApp` is mounted threw `FluxyRoot is not part of the tree`. Hesabak's `boot()` runs behind its `BootGate` and applied the saved dark mode (`AccountService._openPhone`) before `MainApp` built the app; GetX 4 kept the choice in a controller that existed from startup. Now the call is kept and applied when the app mounts (it wins over the mounted config, then stays until the app passes a different theme, like a call after mount); `Fluxy.reset()` forgets it. Hesabak worked around it with `mainCTRL.applyThemeMode()` (skips the call while `Fluxy.context == null`), which can stay or go back to calling `Fluxy.changeThemeMode` directly.

- v1.6.0, from Hesabak and NestCut:
  - **1.** `tool/migrate.dart --material-ui` rewrites the `flutter/material` / `flutter/cupertino` imports; the README has the recipe for packages still on `flutter/material` ("Moving an app that uses flutter/material": bridge, localizations). `FluxyApp(legacyMaterialBridge:)` was not added: the bridge is one line in `builder:` and stays visible as deprecated.
  - **2.** `Fluxy.backToFirst()`: closes dialogs and sheets, then pops to the first page (Hesabak's `popUntil(route.isFirst)` and NestCut's `Get.until((route) => route.isFirst)` sign-out). A "Coming from GetX" row.
  - **3.** The codemod turns deep `package:get/<path>` imports into the whole library, and drops them when the file already imports it.
  - **4.** The codemod drops a `refresh()` that follows, in the same block, a write to the same receiver that always notifies (up to 5 statements apart if they only save the receiver), and lists every other `refresh()`. On Hesabak's GetX code: 38 of 99 dropped, 61 listed. The rest need a person: most are "nudges" after a reload or `persist()` helpers with no write in sight, which the note's 92 counted from reading the call sites.
  - **6.** The rx_edit map helpers are on `RxMap<K, V>`, so untyped `{}.obs` maps (Hesabak's groups) and int keys get `patch`, `addEntry` and the rest.
  - **7.** fluxy_state's README, "Changing state": store the same object back (`items[i] = item`), look it up by identity after an `await`.
  - **8.** fluxy_state no longer exports its own `VoidCallback`; Hesabak's `hide VoidCallback` on orca_secure_storage can go.
  - **9.** fluxy_state's README, "A report over big lists": the scan in a `Computed`. Hesabak's own summary strip and ledger still need it.
  - **10.** `Fluxy.navigator` (and the top-level `navigator`) is the root `NavigatorState?`, null without an app. Hesabak's `rootNavigator` getter can become `Fluxy.navigator`. NestCut's `GlassToast.navigatorKey = Get.key` before `runApp` still needs a change when it moves (`Fluxy.key` throws until the app is mounted): set the key after the first frame, or have GlassToast take `() => Fluxy.navigator`.
  - **11.** Disposing a `FluxyApp` keeps the root scope (`put` / `lazyPut`) and translations, as GetX 4 did; its pages' scopes still close with it. `Fluxy.reset()` clears everything, for tests (DI-PLAN D5). Hesabak's `isRegistered` check in that dispose callback can stay or go.
  - **12.** The codemod lists string literals that name an old GetX name (plain `Get` only before a dot); it also skips `actions-runner` folders (NestCut keeps a runner checkout of itself there).
  - **14.** A rebuilt `FluxyApp` takes a new `locale` / `fallbackLocale`, so NestCut's app-in-`Obx` no longer needs its extra `updateLocale` call (harmless to keep). Translations are still read once.

- v1.5.0, from Hesabak's widget tests (245 of its tests failed on v1.4.0 because of these two):
  - `FluxyApp` called `onReady` from a `Future`, a zero-length timer still pending when a test that pumps once ends ("A Timer is still pending even after the widget tree was disposed"). It now runs from a post-frame callback, as in GetX 4.
  - A rebuilt `FluxyApp` (a parent's build, or a test pumping another app in the same place) ignored its new `home` and themes: the config was read once in `initState`. Now a new `home` replaces the root page (updated in place when it is the same type), and a changed `theme` / `darkTheme` / `themeMode` is applied. A theme set with `Fluxy.changeTheme` / `changeThemeMode` stays until the app passes a different one.

- v1.5.0 (from Hesabak's list-in-`Obx` pattern): a repeated read of the same Rx in one run is one identity check; `RxList` / `RxMap` read methods read the collection once. 2.1–7× on 5,000-row reads.
