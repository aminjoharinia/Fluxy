# fluxy_nav re-engineering plan

Status: done (2026-11-17); decisions below taken. Phases 0-6 done; released as v1.2.0. Results per phase are under "Results" at the end.

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

### Phase 1 (2026-11-17): RouteTable + RouteMatch

- `lib/src/routing/route_table.dart`: a segment trie built once from the pages (children flattened to full paths, parents' bindings / binds / middlewares resolved at build time). Priority static > `:param` > `*wildcard`, with backtracking, regardless of registration order (B1). `:name?` registers both forms. Parameter names come from the matched page's own pattern. Same pattern twice: the first wins. Unmodifiable `routes`; `addPage(s)` / `removePage` rebuild the table, navigation never touches it.
- `lib/src/routing/route_match.dart`: immutable result (uri as path + query, branch with concrete names and `ValueKey(path)` keys, patterns, path / merged parameters, path wins). `RouteMatch.direct` for pages outside the table.
- The delegate matches through the table; `Fluxy.to` / `off` / `offAll` no longer register a temporary page (B4). `FluxyPage.createRoute` only matches again for pages with middlewares, so pages outside the table build directly.
- Removed: `new_path_route.dart` (unused second matcher), `ParseRouteTree`, `FluxyPage.path` / `PathDecoded` (regex patterns). Mixed segments like `file.:ext` are no longer patterns (they match literally).
- Tests: `route_table_test.dart` (14), parse tests moved to the table; B1 and B4 un-skipped. 150 fluxy_nav tests (+5 skipped), all checks green, app 97 tests pass.

### Phase 2 (2026-11-17): NavStack + serial queue

- `lib/src/routing/nav_stack.dart`: `NavEntry` (match, page with its key / `PageSettings` / completer, arguments; `complete` once, a value of the wrong type completes with null; `token` shared by copies under another key) and immutable `NavStack` with pure functions: `push`, `pop` (the last entry stays), `replaceTop`, `popUntil` (keeps one), `removeUntil` (may empty), `remove`, `replace`, `lastAt`, and `add` with the duplicate rules (`reorderRoutes` keeps the old key so the navigator keeps the page, `recreate` takes a new key, `popUntilOriginalRoute`, `doNothing`; `preventDuplicates: false` gets a key of its own). A duplicate is an entry with the same location (path + query).
- `lib/src/routing/nav_queue.dart`: one queue for every navigation. Idle: the task runs right away, so a navigation with no asynchronous middleware changes the stack before the call returns (it used to wait a microtask). Busy: tasks wait in call order (B2). A failing task doesn't block it.
- The delegate keeps a `NavStack` instead of `_activePages` and both stack APIs. One `_commit` puts a new stack in place and completes every entry that left (the popped one with its result, the rest with null). `offAll` / `offAllNamed` / `goToUnknownPage(clear)` drop navigations still waiting for a middleware (they complete with null). The navigator uses `onDidRemovePage` (gesture and `Navigator.pop` remove the entry; the route completes it with the popped value). Notifications sent while a frame is being built (a navigation from `build`) wait for the end of that frame.
- Changed: `offAll(predicate:)` keeps the page the predicate accepts and pushes above it (it used to replace that page); `recreate` really builds the page again; `activePages` / `getVisualPages` removed (use `stack`); `PageSettings.params` is unmodifiable and set when matching.
- Tests: `nav_stack_test.dart` (19: stack functions, duplicate modes, entries, queue order and errors, offAllNamed dropping a waiting navigation, sync application, navigating from `build`); B2 un-skipped. 169 fluxy_nav tests (+4 skipped), all checks green, app 97 tests pass.

### Phase 3 (2026-11-17): delegate, outlets, routing state

- Root navigator pages per entry: an entry gives its own page, or, when its branch marks pages with `participatesInRootNavigator`, the ones marked true; a page given by several entries (a shell) is shown once, where it was given last, so a `Fluxy.to` page goes over the shell and the shell keeps its route across entries. `pickPagesForRootNavigator` now takes the `NavStack`.
- `FluxyRouterOutlet(parent:, initialRoute:, levels:, filterPages:, emptyWidget:, navigatorKey:)` reads the stack: it shows the branch pages below `parent` (concrete or registered path) of the topmost entry that has it, at most `levels` (B6). Its navigator reports pops through `onDidRemovePage`: the entry moves up one level, or pops when the entry below is that page, and the URL follows (B5). No string-keyed delegates; each outlet has its own navigator key. Removed: the generic `RouterOutlet`, `FluxyRouterOutlet.pickPages` / `.builder`, `anchorRoute`, `PagesListExt`.
- `Fluxy.routing` is computed by the root delegate: `current` / `previous` are the paths of the top entry and the one below (nested pages included, B3), `args` the top entry's arguments, `route` the navigator's top route, `isBack` / `removed` from the last change. `isDialogOpen` / `isBottomSheetOpen` come from `FluxyOverlays`, a counter kept by `FluxyDialogRoute` and `FluxyModalBottomSheetRoute` (`CountedOverlay`: counted on install, uncounted on complete or dispose), so an app delegate needs no observer. The delegate always adds its own `FluxyObserver` for logs and route-bound dependencies; `routingObserver` and `ConfigData.routing` are gone; `routingCallback` hears stack changes and overlays.
- `closeAllDialogs` / `closeAllBottomSheets` / `closeOverlay` only pop popup routes (never a page, even if the count is off); `closeAllDialogsAndBottomSheets` now loops while either is open (it needed both).
- A page popped by its navigator (gesture, `Navigator.pop(context, value)`) completes its future with that value.
- example_nav2 uses `FluxyRouterOutlet(parent: '/', levels: 1)` and `FluxyRouterOutlet(parent: Routes.home)`; its test also taps the bottom bar.
- Tests: `outlet_test.dart` (7), routing-state tests, `Navigator.pop` result; B3, B5, B6 un-skipped. 180 fluxy_nav tests (+1 skipped: B7), all checks green, app 97 tests pass (its hand-wired observer is now redundant but harmless).

### Phase 4 (2026-11-17): redirects

- `FluxyRedirect = FutureOr<String?> Function(NavRequest)`: null lets the navigation through, an address sends it there (its own redirects run again, at most 16 hops; a redirect to its own address goes there), `NavRequest.stop` cancels it (stack unchanged, future null). A throwing redirect cancels and is reported through `FlutterError.reportError`, as is a loop.
- `NavRequest`: the `RouteMatch` (`isUnknown`, `path`, `location`, `parameters`), the navigation's `arguments`, `from` (the location before it; null and `isInitial` for the first address).
- Order: `FluxyApp(redirect:)` (also `FluxyCupertinoApp`, or `FluxyDelegate(redirect:)`), then the redirects of the matched page and the pages it's declared under, outer first (resolved in the `RouteTable`, so children inherit; B7). App redirects run for every address, the first one included (the parser hands the delegate a `Uri`), not for `Fluxy.to(() => Page())`. An unknown address that no redirect sends elsewhere opens `unknownRoute`. `FluxyRoot` gives an app-provided delegate the app's `redirect` unless it has one.
- `FluxyPage(onEnter:, onLeave:)`: called with the entry's match when it goes on / leaves the stack (errors reported).
- Removed: `FluxyMiddleware`, `MiddlewareRunner`, `PageRedirect`, `FluxyPage.middlewares` / `unknownRoute`, `RouteDecoder` (`parse_route.dart`), `FluxyDelegate.matchRoute` / `runMiddleware`. The router configuration is now the top entry's `Uri` (`FluxyDelegate extends RouterDelegate<Uri>`, `FluxyInformationParser extends RouteInformationParser<Uri>`); the parser maps an empty address, and `/` when `redirectRootToInitialRoute`, to `initialRoute`. `FluxyApp` sets that flag when given an `initialRoute` or when `/` is not a page.
- example_nav2: `ensureAuth` / `ensureNotAuthed` page redirects (`lib/app/redirects`), a test for the login redirect.
- App (`lib/main.dart`, uncommitted): its own delegate, the parser subclass, `_RootRoutingObserver`, `UnknownRoute` and `leaveUnknownStartAddress` replaced by `redirect: appRedirect` with `appRedirect = (r) => r.isUnknown || r.path == '/' ? startRoute() : null`. Analyzer clean, 97 tests pass.
- Tests: `redirect_test.dart` (15), `app_shape_test.dart` rewritten for the `redirect:` set-up (7, including the address the app opens at); B7 rewritten for redirect order and un-skipped, no skipped tests left. 193 fluxy_nav tests, all checks green.

### Phase 5 (2026-11-17): files, facade, docs

- `lib/get_navigation/` is gone. Layout: `lib/src/routing/` (fluxy_page, page_settings, route_table, route_match, nav_stack, nav_queue, nav_request), `router/` (fluxy_delegate, information_parser, fluxy_navigator, router_outlet, navigation_interface, route_observer, route_report, url_strategy), `overlays/` (dialog_route, bottom_sheet_route, snackbar, snackbar_controller, overlay_tracker), `app/` (fluxy_app, fluxy_cupertino_app, fluxy_root, modules, reset, test_kit), `transitions/` (transition_mixin, default_transitions, page_route, transition, custom_transition, circular_reveal_clipper; code unchanged). `lib/fluxy_nav.dart` lists every export.
- The 1,488-line facade is one extension per concern in `src/facade/`: `FluxyNavigationExt` (pages, back, routing state, defaults), `ExtensionDialog` (+ `isDialogOpen`, `closeDialog`, `closeAllDialogs`), `ExtensionBottomSheet` (+ `isBottomSheetOpen`, `closeBottomSheet`, `closeAllBottomSheets`), `ExtensionSnackbar` (+ `isSnackbarOpen`, `closeAllSnackbars`, `closeCurrentSnackbar`), `OverlayExt` (`showOverlay`, `isOverlaysOpen`, `closeOverlay`, `closeAllOverlays`, `close`), `FluxyAppExt` (locale, theme, `context`, `overlayContext`), `FluxyWindowExt` (window metrics). The commented-out `config` block is gone.
- `FluxyTestMode` is exported; `example/` no longer has a `fluxy_nav` dev dependency.
- Docs: FLUXY.md v1.2.0 entry, root README (navigation bullet, Coming from GetX rows for middleware and outlets), `packages/fluxy_nav/README.md` (pages, redirects, nested pages, overlays, tests).
- A test for an independent navigator through `id:` (`Router(routerDelegate: Fluxy.nestedKey('/tabs'))`, `toNamed(..., id:)`, `back(id:)`). 194 fluxy_nav tests, all checks green, app 97 tests pass.

### Phase 6 (2026-11-17): benchmarks, release

- `benchmark/nav/`: a release macOS app (match, push + pop, push 100 deep, deep link, dialog) and `run.sh`, which builds it for this checkout and for an older ref from a temporary worktree and runs them alternately. Against v1.0.0 (4 runs each): matching 15.2× faster (1.25 vs 18.97 µs over 152 pages), deep link 2.0×, push + pop 1.13×, push 100 deep 1.03×, dialog equal. The frame dominates the last three.
- Found while measuring: the root pages were merged with an O(n²) loop (a flat app now skips merging; others use an insertion-ordered map), and `offNamed` / `off` / `offAll(predicate:)` / page pops could put two entries with the same key on the stack (they now follow the duplicate rules; `NavStack.replaceTopWith`). 196 fluxy_nav tests.
- Released as v1.2.0: root and package pubspecs, FLUXY.md / README `ref:` snippets.

## For the app (BOOFI)

`lib/main.dart` (left uncommitted): `routerDelegate: appRouterDelegate`, `routeInformationParser: appRouteParser` and `unknownRoute: appUnknownRoute` become `redirect: appRedirect`, with

```dart
String? appRedirect(NavRequest request) => request.isUnknown || request.path == '/' ? startRoute() : null;
```

`appUnknownRoute`, `appRouterDelegate`, `appRouteParser` / `_AppRouteParser`, `_RootRoutingObserver`, `UnknownRoute`, `leaveUnknownStartAddress()` (and its call in `main()`) and the `SynchronousFuture` import are deleted. Nothing else in the app uses the removed API.

## Deferred

Done after the v1.2.0 review (2026-11-18, unreleased; see FLUXY.md): `IGetNavigation` is `FluxyNavigation` and the stale `GetMiddleware` mapping is gone; browser back / forward goes back to an address already on the stack instead of reordering (by address, not by `RouteInformation.state`); system back closes a dialog on an outlet's navigator first.

Still open: `routingCallback` hears every stack change and overlay change, not the observer's per-route events. Browser history is matched by address, so two history entries with the same address can't be told apart.
