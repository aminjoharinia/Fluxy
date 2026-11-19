# fluxy_state DI re-engineering plan

Status: done (2026-11-18); released as v1.4.0. Results per phase are under "Results" at the end.

## Why

Dependency injection in fluxy_state is still upstream GetX 5's: one global static map (`Inst._singl`), lifetimes decided by whichever route was installed last (`RouterReportManager._current`), plus a second, widget-based system (`Bind` / `Binder` / `Binds`) that writes into the same global map. The bugs below were confirmed with throwaway tests on v1.3.0:

| # | Bug | Cause |
|---|---|---|
| B1 | A controller made by `Fluxy.put` is closed (`onClose`, owned workers disposed) when the route where it was first used goes away: the page is popped, a dialog it was first read in closes, or `offAll` / `offAllNamed` replaces the root page. Code that kept a reference (a top-level `final c = Fluxy.put(C())`) goes on using the closed instance; going back home after `offAllNamed` shows the same closed instance | The first `find` links the instance to `RouterReportManager._current` (the last route installed); `reportRouteDispose` deletes every instance linked to that route |
| B2 | `Fluxy.put(C(2))` while a `C` is registered ignores the new instance (never started) and returns the old one | `_insert` returns early unless the old entry is "dirty" |
| B3 | `Fluxy.replace` / `lazyReplace` of a `FluxyService` does nothing | `delete` refuses services without `force`, then `put` is ignored (B2) |
| B4 | `Fluxy.reset()` / `resetInstance()` drop instances without calling `onClose`: workers, streams and timers of controllers leak across tests | `_singl.clear()` |
| B5 | `reloadAll` / `reload` of a `put` instance: no `onClose`, and the same object comes back without `onInit` running again | The builder of a `put` is `() => dependency`; the lifecycle guard skips `onStart` |
| B6 | Two `FluxyBuilder<C>(init: ...)` on screen: when the first unmounts, the shared controller is closed and unregistered while the second still shows it; the second's `init` is never used | `BindElement` counts no owners: the creator deletes on unmount |
| B7 | A `lazyPut` found on a page is unregistered when that page goes away; the next `find` throws | SmartManagement.full deletes the factory too (unless `fenix`) |
| B8 | `find` of a missing type throws a `String`; `isPrepared` logs an error for an unregistered type | Upstream |

Also: `_current` is never restored when a route goes away, so after a dialog closes the "current route" is a dead route.

Design debt behind those:

- **Lifetime is implicit and global.** Whether an instance lives for the app, a page or a dialog depends on which route happened to be installed last when it was first read, plus a global `SmartManagement` mode, `permanent`, `fenix`, and the `isDirty` / `lateRemove` dance for re-registering during a transition.
- **Two DI systems.** `Bind` / `Binder` look like scoped (InheritedWidget) DI but register globally; a "local" binder (`global: false`) still calls `Fluxy.spawn`. `FluxyWidget` / `WidgetCache` and `Module` / `Dependencies` are two more variants.
- **The state package knows routes through a side channel.** fluxy_nav calls `RouterReportManager.reportCurrentRoute` / `reportRouteDispose` from `FluxyPageRoute`, `FluxyDialogRoute`, the bottom sheet route, `RouteReportMixin` and `ModuleState`; the navigation history (`NavStack`) isn't involved.
- **Untyped keys.** String `tag`s, `key: Object?` parameters "for internal usage".
- **Dead code.** Commented-out `injector`, `BindingsBuilder`, `_factory`, filter extension.

## What the BOOFI app uses (keep these working)

From the app's `lib/`: `Fluxy.put(XController())` ×20, all as top-level finals (`final CTRLPlaces = Fluxy.put(PlacesController());`), so each is created on first access, wherever that happens; 20 `FluxyController` subclasses; `onClose` ×1 (`PlacesController` removes its direct listeners there). Nothing else: no `find`, `lazyPut`, `delete`, tags, bindings, `Bind`, `FluxyView`, `FluxyBuilder`, `FluxyWidget`, `SmartManagement`.

The app wants app-lifetime singletons and is exposed to B1: after a sign-out (`offAll` / `offAllNamed`, used 7 times) every controller first read on the old root page, `PlacesController` among them, is closed, and the app keeps using it. `PlacesController.onClose` has removed its listeners by then, so its slices stop following the stored data. Controllers first read inside a dialog are closed when the dialog closes.

## Target design

Same everyday API (`Fluxy.put`, `lazyPut`, `find`, `delete`, `FluxyController`, `onInit` / `onReady` / `onClose`, `own`), new internals.

1. **`DependencyContainer`: one registry, plain Dart.** No Flutter, no routes. Entries are `instance`, `lazy` (built on first `find`, kept) and `factory` (`spawn`: a new one per `find`). Clear rules, unit-tested without widgets:
   - `put` of a type already registered: per D2.
   - `delete` closes the instance (`onDelete`) and removes the entry; a lazy entry keeps its factory unless removed (`fenix` is the default, D3).
   - `replace` closes the old one and registers the new one, services included.
   - `reset` closes every instance, newest first, then clears.
   - Typed errors: `DependencyNotFound` (a `FlutterError` naming the type, tag and the scopes searched).
2. **Scopes instead of route-linking.** A `FluxyScope` is a container with a parent. The root scope lives as long as the app: `Fluxy.put` / `lazyPut` register there and stay until deleted (D1), which fixes B1 and B7. Child scopes are explicit:
   - **Page scopes.** A `FluxyPage` with `bindings` / `binds` (or `scoped: true`) gets a scope when its entry goes on the `NavStack` and loses it when the entry leaves (the delegate's `_commit` already knows both moments). Its bindings register there. Dialogs and sheets get no scope unless asked.
   - **Widget scopes.** `Binds` / `FluxyScope(child:)` give a subtree its own scope, closed on unmount.
   - **Lookup** walks from the innermost scope to the root: `context.find<T>()` from the context's scope, `Fluxy.find<T>()` from the top page's scope.
   - `RouterReportManager`, `SmartManagement`, `isDirty` / `lateRemove` and the route report mixins go away.
3. **Owners, counted.** `FluxyBuilder(init:)`, `Binder`, `FluxyWidget` register as owners of what they create; the instance closes when its last owner goes (B6), unless it belongs to a scope.
4. **Typed handles (optional sugar).** `final places = Dep(() => PlacesController());` then `places()` / `places.of(context)`; a handle is its own key, so no string tags and no type collisions. Tags stay for existing code.
5. **Test overrides.** `Fluxy.override<Api>(FakeApi())` (or a test scope) replaces a registration for a test; `reset` restores and closes everything.
6. **Files.** `lib/src/di/` (container, scope, entry, errors, handle, facade) and `lib/src/di/widgets/`; the `get_instance/` paths go, like nav's `get_navigation/` did.

Kept as is: `FluxyLifeCycleMixin` (`onInit` / `onReady` / `onClose`, `own`, `onDispose`), `FluxyController` / `FluxyService`, `Fluxy.put` / `find` / `lazyPut` / `delete` / `isRegistered` signatures (minus `key:` / `fenix:` per D3), `Bindings` / `Binding`.

## Phases

Each phase ends green: every package, both examples, root, tool, and the app copy (`pubspec_overrides.yaml`) with its 97 tests. One release at the end.

0. **Characterization tests.** Pin what the app relies on: a top-level `put` survives page pops, dialogs, `offAll` (failing today: B1, marked `skip`), lifecycle order (`onInit`, `onReady` after the frame, `onClose` once), `own()` disposal, `FluxyBuilder` / `Obx` with put controllers. B1-B8 as tests, marked `skip` until fixed.
1. **`DependencyContainer`.** The registry and its rules, pure Dart, behind the current `Inst` facade. Fixes B2-B5, B8. Dead code out.
2. **Scopes and lifetimes.** Root scope for `put` / `lazyPut`; page scopes owned by `NavStack` entries (fluxy_nav hands entries their scope; `FluxyPageRoute` / dialog / sheet stop reporting). `RouterReportManager` and `SmartManagement` removed. Fixes B1, B7.
3. **Widget scopes and owners.** `Binds` / `Binder` / `FluxyBuilder(init:)` / `FluxyWidget` / `Module` onto scopes with owner counts. Fixes B6.
4. **Typed handles and overrides** (per D4).
5. **Files and docs.** `lib/src/di/`, FLUXY.md, fluxy_state README, Coming from GetX rows (`SmartManagement`, `fenix`, route-linked deletion).
6. **Benchmarks and release.** `find` is on the hot path (`FluxyView.controller` in build): measure `find` / `put` / `delete` and a page with bindings against v1.3.0 (benchmark app, runs alternated); release notes, tag, app switch.

## Decisions

- **D1: A plain `Fluxy.put` / `lazyPut` lives as long as the app** (until `delete`; 2026-11-18, user's choice after the speed / memory comparison: route-linking frees nothing while code holds a reference, as BOOFI's top-level controllers do). Page lifetimes come from page `bindings` (a page scope).
- **D2: `put` of a type already registered: replace** (2026-11-18, user's choice): the old instance is closed, the new one registered and started, with a debug log.
- **D3: `SmartManagement` and `fenix` are removed** (2026-11-18): lazy factories are kept after `delete` (today's `fenix: true`); page and widget scopes cover the rest.
- **D4: v1.4.0, with typed handles and test overrides** (2026-11-18): breaking where it buys correctness, as with v1.2.0.
- **D5: disposing a `FluxyApp` keeps the root scope and translations** (2026-11-19, follow-up to D1, found moving Hesabak): it closes only what the app set up (its navigator, so its pages' scopes, overlays, snackbars). An app remounted later finds the controllers it put in `main()`, as in GetX 4. `Fluxy.reset()` clears everything, for tests. Released in v1.6.0.

## Results

### Phase 0 (2026-11-18): characterization tests

- `packages/fluxy_nav/test/di/di_routes_test.dart`: lifecycle (`onInit` once, `onReady` after the frame, `own()` disposed on delete, `onClose` once), page bindings closing with the page (a `Binding` with `Bind.lazyPut`, and a void binding calling `Fluxy.put`), B1 (top-level put through a popped page, a dialog, `offAllNamed`), B6, B7. `packages/fluxy_state/test/instance/di_bugs_test.dart`: B2-B5, B8. Bugs skipped until fixed.
- Found while writing them: `void dependencies() => Fluxy.put(C())` infers `put<void>` and registers under `void`.

### Phases 1-3 (2026-11-18): container, scopes, owners

- `lib/src/di/scope.dart`: `FluxyScope` (entries `instance` / `lazy` / `factory`, `put` replaces, `lazyPut` ignored when registered, `delete` keeps a lazy builder unless forced, `reload`, `close` newest first, spawned instances closed with their scope, `DependencyNotFound`, `put<void>` / `<dynamic>` / `<Object?>` rejected). `facade.dart`: the `Fluxy` extension on top (`find` is one map lookup with no open scope). `widgets.dart`: `DependencyScope`, `ScopeProvider`, `context.find`.
- Lifetimes: root scope for `put` / `lazyPut`; `FluxyPageRoute` makes a page scope when the page has bindings / binds, runs them inside it (all `List<Bind>` bindings now wrap the page; only the last one did) and closes it on dispose. `Module`, `RouteReport(dependencies:)` on scopes. Dialogs, sheets and the observer no longer report routes.
- `Binder` / `FluxyX` keep the entry they own (created, a not yet built `lazyPut`, `Bind.put`, or one another widget created) and count owners; a non-global binder's controller is local.
- Removed: `RouterReportManager`, `SmartManagement`, `fenix`, `markAsDirty`, `RouteReportMixin` / `PageRouteReportMixin`, `key:` on `delete` / `reload`.
- B1-B8 un-skipped and passing. Old tests that pinned GetX behaviour rewritten: a `put` in a build method now stays (`dispose_dependencies_test.dart` also checks page bindings), `lazyPut` keeps its builder, errors are `DependencyNotFound`.

### Phase 4 (2026-11-18): handles and overrides

- `lib/src/di/dep.dart`: `Dep<T>` (its own key; `call()` registers lazily in the root on first use; `of(context)`, `register()`, `put()`, `delete()`, `overrideWith()`). `Fluxy.overrideWith<T>` / `clearOverrides` (a detached override scope checked first; `resetInstance` drops it and closes its instances).
- `test/instance/di_scope_test.dart` (19): container rules, scopes, `DependencyScope`, handles, overrides.

### Phase 5 (2026-11-18): files and docs

- `fluxy_state/lib/get_instance/` is now `lib/src/di/`. FLUXY.md v1.4.0 entry, fluxy_state README "Dependencies", root README (dependencies bullet, Coming from GetX rows for `SmartManagement`, `fenix`, `RouterReportManager`).

### Phase 6 (2026-11-18): benchmark, release

- `benchmark/nav` gained `di find`, `di put + delete`, `di lazyPut + find + delete` and `page with bindings push + pop`. Against v1.3.0 (release, runs alternated, best median of 4): `find` 1.36× faster (0.01 µs), `put + delete` 1.96× (0.65 µs), `lazyPut + find + delete` 1.85× (0.68 µs); a page with bindings 0.99× and the navigation scenarios 0.93-1.05× (the frame dominates; noise).
- All packages, root, both examples and the app copy (97 tests) green.

