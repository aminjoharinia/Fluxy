# fluxy_nav re-engineering plan

Status: in progress (2026-11-17); decisions below taken. Phase 0 done. Results per phase are under "Results" at the end.

## Why

fluxy_nav is still upstream GetX 5's router with fixes added on top. It's about as big as fluxy_state (8.4k lines) but has far fewer tests behind it. The bugs below were confirmed with throwaway tests on v1.0.0 + `aa4b84f9`:

| # | Bug | Cause |
|---|---|---|
| B1 | With `/:id` registered before `/settings`, `/settings` opens the `/:id` page with `id = settings` | `ParseRouteTree._findRoute` takes the first regex match in the order pages were registered |
| B2 | `toNamed('/a')` (async middleware) then `toNamed('/b')` leaves the stack as `[/, /b, /a]` | Navigations aren't queued: each one awaits its middleware, then appends to the shared list |
| B3 | Inside nested pages, `Fluxy.currentRoute` is `/` while the address is `/x` | `Fluxy.routing` comes from the root `Navigator`'s observer, which only sees the root page, not the router's location |
| B4 | Every open `Fluxy.to(() => Detail())` adds `/Detail` to the global route table until it closes; two open copies add it twice | `to()` / `off()` / `offAll()` register a temporary page so the matcher can "find" it |
| B5 | A pop inside a `FluxyRouterOutlet` navigator only removes the visual route; the delegate's stack and the URL keep it | The outlet's `onPopPage` just returns `didPop` |
| B6 | `FluxyRouterOutlet` without `anchorRoute` shows `branch.skip(n).take(n)` | Upstream bug; it works only for depth 1 |
| B7 | `FluxyMiddleware.priority` is ignored on the router path, and so are `redirect` (sync), `onPageCalled` and `onBindingsStart` | Two middleware systems: the Navigator 1 `MiddlewareRunner` / `PageRedirect` and the router's `redirectDelegate` |

Design debt behind those:

- **Two stack APIs in one class.** `_push` / `_popWithResult` and the older `_pushHistory` / `_unsafeHistoryAdd` / `_popHistory` each handle duplicates their own way. `PopMode.page` uses the old one, everything else the new one.
- **"Immutable" types that mutate.** `RouteDecoder` is `@immutable` but its branch list is edited through a `route` setter. `PageSettings.params` is a mutable map that matching clears and refills.
- **Dead code.** `new_path_route.dart` (247 lines: a second matcher, `RouteTree`, `RouteNode`) is never used, and there are many commented-out blocks.
- **One giant facade.** `extension_navigation.dart` (1,488 lines) holds dialogs, sheets, snackbars, navigation, theme, locale, window metrics and overlays.
- **Deprecated Flutter API.** `Navigator.onPopPage` (`// ignore: deprecated_member_use`) instead of `onDidRemovePage`.
- **Nested navigation depends on global singletons.** `Fluxy.nestedKey(route)` creates a delegate per string, and `RouteDecoder.fromRoute` reads `Fluxy.rootController`.

## What the BOOFI app uses (keep these working, with no or mechanical changes)

From the app's `lib/`: `Fluxy.back` ×128, `closeAllDialogs` ×78, `defaultDialog` ×60, `dialog` ×40, `to` ×8, `key` ×7, `bottomSheet` ×6, `offAll` ×5, `offAllNamed` ×2, `isDialogOpen` ×2, `generalDialog` ×2, `context` ×3, `routing` ×1. In `main.dart`: `FluxyApp.router` with its own `FluxyDelegate`, a `FluxyInformationParser` subclass, a hand-wired `FluxyObserver`, 6 flat `FluxyPage`s, `unknownRoute`, and `Transition.cupertino` / `zoom`. No outlets, no middleware, no path parameters.

The app is overlay-heavy and page-light. Three `main.dart` workarounds remain because the router can't express them:

1. A parser subclass that sends `/` to `startRoute()`, which depends on sign-in.
2. An `UnknownRoute` page that redirects in a post-frame callback.
3. A wrapper so `Fluxy.routing` works with an app-provided delegate.

A good redesign should delete all three.

## Target design

Same public shape (`FluxyApp`, `FluxyPage`, `Fluxy.to` / `toNamed` / `back` / `off*` / `dialog` …), new internals.

1. **`RouteTable`: a trie matcher.** Segments are matched by priority (static > `:param` > `*` wildcard), regardless of registration order (fixes B1). It's built once from `getPages` (children flattened, inherited middlewares and bindings resolved at build time) and never changed by navigation (fixes B4). The result is a `RouteMatch` with the page chain, path params and query params, all immutable.
2. **`NavStack`: an immutable history.** A list of `NavEntry` (match + arguments + completer + key). It's the single source of truth for the root navigator, the nested outlets, the URL and `Fluxy.currentRoute` (fixes B3). The push / replace / pop / removeUntil / duplicate policies are pure functions over the list, unit-tested without widgets.
3. **One queue for navigation.** Every navigation call goes into a serial queue: redirects resolve in order and the stack changes in call order (fixes B2). A navigation that's superseded while its redirect is still pending completes with `null`.
4. **Redirects instead of middleware.** One async hook, `FutureOr<String?> redirect(NavRequest)`, per page (inherited by children), plus an app-wide `FluxyApp(redirect: …)` that also runs for the first address. Optional `onEnter` / `onLeave` callbacks replace the page-build hooks. `priority` is honoured, or dropped (D3). This replaces the parser subclass and the `UnknownRoute` hack: `redirect: (r) => r.isUnknown || r.path == '/' ? startRoute() : null`.
5. **`FluxyDelegate` becomes thin.** It maps `NavStack` to `Navigator.pages` and uses `onDidRemovePage`, so gesture, system-back and `Navigator.pop` all go through the stack. `Fluxy.to(() => Widget)` makes an entry holding the builder directly, with no route-table registration; its location is `/Detail` as today.
6. **Outlets read the stack.** A `FluxyRouterOutlet(parent: '/home')` shows the entries below that prefix and reports pops back to the queue (fixes B5 and B6). No string-keyed global delegates are needed for outlets; `id:` / `Fluxy.nestedKey` survive only for apps with independent navigators (D4).
7. **`Fluxy.routing` comes from the router.** `currentRoute`, `previousRoute`, `args` and `parameters` are read from `NavStack`. `isDialogOpen` / `isBottomSheetOpen` are read from the overlay layer (a counter kept by `FluxyDialogRoute` / the bottom sheet route), so an app delegate no longer needs a hand-wired observer.
8. **Overlays stay functionally the same.** Dialogs, sheets and snackbars keep their API. They move to their own files and stop depending on route bookkeeping. `back()` keeps the order popup → page → nothing.
9. **File layout.** `routing/` (table, match, stack, queue, redirect), `router/` (delegate, parser, outlet, navigator), `overlays/` (dialog, sheet, snackbar), `app/` (FluxyApp, FluxyCupertinoApp, root), `transitions/` (unchanged code, moved). The facade is split into one extension per concern. The `get_*` paths in this package go away at the same time (D2).

Kept as is: the transition code (`get_transition_mixin.dart`, `default_transitions.dart`, the Cupertino back gesture), `FluxyHeroScope`, the snackbar queue, `Transition` values, `FluxyPage` fields the app uses.

## Phases

Each phase ends green: package tests, the examples, and the app copy with `pubspec_overrides.yaml` running its 97 tests. One release at the end (as with the rename).

0. **Characterization tests.** Pin current behaviour the app relies on: `back` order (snackbar, dialog, sheet, page, last page kept), `closeAllDialogs`, `offAll` with transitions, `to` results and duplicates, futures completing on removal, `offAllNamed`, unknown → `unknownRoute`, web hash URLs, `Fluxy.key` / `Fluxy.context`. Plus failing tests for B1–B7, marked `skip` until fixed.
1. **`RouteTable` + `RouteMatch`.** New matcher behind the current delegate (`matchRoute` delegates to it). Fixes B1 and B4. Delete `new_path_route.dart` and `ParseRouteTree`.
2. **`NavStack` + queue.** Replace `_activePages` and both stack APIs. Fixes B2. Duplicate modes become stack functions with unit tests.
3. **Delegate / outlet / Navigator 2 cleanup.** `onDidRemovePage`, outlets reading the stack, `Fluxy.routing` from the stack and the overlay counter. Fixes B3, B5 and B6.
4. **Redirects.** `redirect` on pages and on `FluxyApp`. Old middleware handled per D3. Fixes B7. The app's three `main.dart` workarounds become one `redirect:`.
5. **Split and rename files.** Facade split, folders, `get_*` paths removed (D2), docs (FLUXY.md, package README, example_nav2 updated to outlets with `parent:`).
6. **Benchmarks + release.** Push / pop / deep-link timings against v1.0.0 (benchmark app), release notes, tag, app switch.

## Decisions (2026-11-17)

- **D1: Version v1.2.0, breaking changes allowed** where they buy correctness (middleware, nested ids, `RouteDecoder` internals). The app needs a small `main.dart` change. (User's call: v1.2.0, not v2.0.0.)
- **D2: Rename the internal paths now.** `lib/get_navigation/...` becomes `routing/`, `router/`, `overlays/`, `app/` and `transitions/`. `FluxyTestMode` gets a public export, and `example/` drops its `fluxy_nav` dev dependency.
- **D3: `FluxyMiddleware` is removed.** It's replaced by `redirect` on pages and on `FluxyApp`, plus `onEnter` / `onLeave`. There's no adapter. `priority` goes with it, and redirects run parent first, in the order they're listed.
- **D4: `id:` stays, for independent navigators only** (for example tabs with their own history). Outlets read the main stack and need no id.
- **D5: Router only.** Both app widgets keep running on `MaterialApp.router` / `CupertinoApp.router`. No plain-`Navigator` mode.

## Results

### Phase 0 (2026-11-17): characterization tests

- `test/navigation/characterization_test.dart` (21 tests): `back` order (snackbar, dialog, page, last page kept; sheet before page; sheet on the first page), `closeAllDialogs` (two dialogs; none open leaves the page; dialog over a sheet), overlay results (`dialog`, `defaultDialog` confirm, `generalDialog` + `closeDialog`, `bottomSheet`), pages (`to` with a transition and its result, `to` duplicates, `offAll` with zoom + duration completing the removed futures, `offAllNamed`, unknown → `unknownRoute`, `currentRoute` / `previousRoute`, `arguments`, `initialRoute`), globals (`Fluxy.key`, `context`, `overlayContext`, the URL the delegate reports, hash URLs by default).
- `test/navigation/app_shape_test.dart` (4 tests): the app's `main.dart` set-up as of v1.0.0 (own delegate, parser subclass with a start route, `UnknownRoute` post-frame redirect, hand-wired observer). Replaced in phase 4 by the `redirect:` version.
- `test/navigation/nav_bugs_test.dart`: B1-B7 as tests, all confirmed failing on v1.0.0 and marked `skip` until fixed.
- All checks green: 134 fluxy_nav tests (+7 skipped), every package, root, both examples; the app with a local override: analyzer clean, 97 tests pass.
