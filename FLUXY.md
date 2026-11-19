# Fluxy

Fluxy is a fork of [GetX](https://github.com/jonataslaw/getx) (from commit `a294d2f`), split into separate packages so each project can depend on only what it needs.

| Package | What it holds | Depends on |
|---|---|---|
| [`fluxy_core`](packages/fluxy_core) | `Fluxy` object, logging, engine, `Equality` | — |
| [`fluxy_state`](packages/fluxy_state) | Rx, `Obx`, `Computed`, `RxFuture`, controllers, workers, DI, copy-on-write edits | core |
| [`fluxy_i18n`](packages/fluxy_i18n) | `Translations`, `.tr`, locale state | core, state |
| [`fluxy_utils`](packages/fluxy_utils) | `FluxyPlatform`, validators, extensions, queue | core |
| [`fluxy_nav`](packages/fluxy_nav) | router, `Fluxy.to/back`, dialogs, sheets, snackbars | core, state, i18n, utils |
| [`fluxy_ui`](packages/fluxy_ui) | responsive views, `hp`/`wp`, animations | core, state, utils |

The root package `fluxy` re-exports all of them: `import 'package:fluxy/fluxy.dart'` (named `get`, with GetX's type names, up to v0.7.3; see the README's "Coming from GetX").

## Using it

Everything:

```yaml
fluxy:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v1.5.0
```

Only one package (for example state management):

```yaml
fluxy_state:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v1.5.0
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
- v0.5.0:
  - Translations (fluxy_i18n, ideas from Sint):
    - `.tr` is reactive: an `Obx` showing translated text rebuilds when the locale or dictionaries change. `Get.translationVersion` exposes the signal. fluxy_i18n now depends on fluxy_state for this.
    - `.tr` looks in a cached list of dictionaries for the current locale (same lookup order as before), rebuilt only after a change, instead of scanning all dictionaries on a miss.
    - `appendTranslations` copies instead of modifying, so it works after `const` dictionaries; `addTranslations` stores copies too.
    - `.trParams` makes one pass: a placeholder only matches a whole name (`@admin` no longer eats `@admin_email`), inserted values are not replaced again, names may contain `-`.
    - `Get.updateLocale(l, rebuildAll: false)` skips the full-app reassemble. The default stays `true`: widgets that read `.tr` in a plain `build` need it.
    - A device-language change no longer overrides a locale the app set itself. `GetMaterialApp` / `GetCupertinoApp` follow the device only when no `locale:` is given, or when `followDeviceLocale: true`; `followDeviceLocale: false` never follows.
  - Navigation (fluxy_nav):
    - Routes match the whole path: an unknown address (`/nope`, `/Home/x`) used to show its closest registered parent and never reached `unknownRoute`.
    - `GetMaterialApp.router` / `GetCupertinoApp.router` take `initialRoute`, and an explicit `initialRoute` wins over a registered `/`.
    - The `Get.routing` observer (`Get.isDialogOpen`, `Get.currentRoute` ...) is added to an app-provided `routerDelegate` too.
    - Web uses hash URLs by default (Flutter's default); path URLs need `setUrlStrategy()` before `runApp`, and a late call logs a message instead of asserting. Fixed an infinite recursion in `removeLastHistory`.
    - Transitions curve with `animation.drive(CurveTween(...))` instead of a `CurvedAnimation` per build (which left a listener on the route animation each time).
    - `Get.showOverlay` removes its overlay when the task throws any error, not only an `Exception`.
    - Path parameters win over query parameters (`/item/42?id=7` keeps `id = 42`).
    - `Get.reset()` moved here from the umbrella package (it resets state and translations).
  - State (fluxy_state):
    - `ever` / `listen` / workers keep working after all of an Rx's workers were disposed (the stream used to unhook forever).
    - Copy-on-write edit helpers: `mapWith`, `listWith`, `listWithout`, `listReplaced`, `updatedIn`, `RxList.patch / replaceItem / reorder`, `RxMap.patch / addEntry / removeEntry...`, documents `setIn / updateIn / patchIn / editListIn`, `RxSlice`, `watchRx`.
    - Debug builds warn when an Rx is given the same Map / List / Set object it already holds (an in-place edit that will not notify).
    - `Computed`: a cached derived value that follows what it reads and notifies only when its result changes.
    - `RxFuture`: an async load as an Rx (`loading` / `success` / `error`), keeping `lastData`; only the newest load counts.
  - Repo: tests live in each package (`packages/*/test`), CI analyzes and tests every package on its own, Fluxy README.
- v0.6.0 (fluxy_state fixes):
  - `Obx` no longer calls `markNeedsBuild` on an unmounted element when an Rx changes in the frame that removes it.
  - `GetBuilder` follows a changed `id` (it kept listening to the old one unless `global: false`).
  - `Bind.put` / `Bind.spawn`: `permanent: false` now removes the instance on unmount; the flag was inverted.
  - `rx.bindStream` returns its `StreamSubscription` and is cancelled on `close()` or when the stream is done, also when bound outside a build (for example in `onInit`).
  - `rx.trigger(sameValue)` notifies every listener (Obx, GetBuilder, workers), not only the stream.
  - `listenAndPump` pumps the current value to its own subscriber only.
  - `rx.update` / `Value.update` notify when the callback edits the object in place and returns it.
  - `debounce` / `interval`: a callback still waiting for its delay is dropped on `dispose()`.
  - `StateMixin.futurize`: only the newest call counts, one notification per result, and the error keeps the thrown object (or `errorMessage` if given). Setting `status` inside a build no longer subscribes it.
  - `Computed`: a throwing compute no longer breaks the source's other listeners (the error is thrown at the next read), and it unsubscribes from its sources when its last listener leaves.
  - `onReady` is skipped when the controller is deleted before the next frame, and `onInit` asks for a frame so `onReady` doesn't wait on an idle app.
  - `disposeId` / reading an unregistered group id no longer crash on a null check.
  - `rxn(null)` sets a nullable Rx to null (`call` used to ignore `null`); `rx()` still reads, `null` on a non-nullable Rx is still ignored, and a wrong-type argument throws `ArgumentError`.
- v0.6.1:
  - `rx(v)` is typed again: `T call(T v)` with a required argument. `count('abc')` and `count(null)` on a non-nullable Rx are compile errors (v0.6.0 only caught a wrong type at runtime), and `rxn(null)` still sets null. `rx()` no longer reads; use `rx.value`.
- v0.6.2:
  - Navigation: `Get.to` fixes for `preventDuplicates` and for pages of the same class; the futures of pages removed by `offAllNamed` / `offNamedUntil` / `off` / reorder / `removeRoute` complete; `popUntilOriginalRoute` works; `GetPage.copyWith` keeps `preventDuplicateHandlingMode` and `restorationId`; `Get.back` never pops the last page.
  - Utils / snackbars: `GetQueue` survives a job that throws an `Error` and fails jobs that are cancelled; `closeAllSnackbars` no longer shows the next queued snackbar.
  - `setSuccess` / `status = success` always notify, so a list edited in place and passed again updates the UI (the deep comparison treated it as unchanged). Calling `setSuccess` twice with equal data now notifies twice; other statuses still skip unchanged values.
  - Performance: an `Obx` schedules one rebuild microtask however many Rx values change; `ListNotifier` copies its listener list only when listeners change during a notify (it used to copy on every notify); `GetPage.path` is compiled on first use and `matchRoute` copies each page once, so a navigation no longer recompiles route regexes.
- v0.7.0:
  - `Computed` is glitch-free (push-pull). A source change only tells it that it may be out of date; it recomputes on read (right away while listened to), after bringing any `Computed` source up to date. With `b`, `c` derived from `a` and `d = b + c`, a change of `a` recomputes `d` once and never shows it a new `b` with an old `c`.
  - Every Rx / notifier has a `reactiveVersion`; a `Computed` recomputes only when a source's version moved (a global version skips the check when nothing changed at all). A `Computed` with no listeners keeps its source record without subscriptions, so a read after unrelated changes does not recompute.
  - `Computed` reads inside `Get.batch` see the held changes; its listeners are notified once after the batch. Errors are kept and rethrown at each read until a source changes.
  - `effect(() { ... })`: runs now and again when what it read changes; synchronous, but once per notify / batch and after the change is fully applied. It may return a cleanup (run before the next run and on `dispose()`). Its writes are held until it returns; an effect that keeps re-triggering itself is stopped with a `StateError`; errors after the first run go to `FlutterError.reportError`.
  - A listener that throws is reported with `FlutterError.reportError` and the other listeners still run, also inside `Get.batch` (as with `ChangeNotifier`). It used to stop the notify, so later listeners (other `Obx`, workers, `Computed`) missed the change, and the error was thrown into the code that wrote the Rx.
  - Writing a closed Rx (`value =`, `rx(v)`, `update`, `trigger`) throws a `FlutterError` in debug builds; release builds still ignore the write. It was silently ignored, which hid callbacks that outlived their widget or controller (`refresh()` and collection edits already asserted).
  - Controllers own what they create: effects, `Computed`s and workers made inside `onInit` / `onReady` are disposed right after `onClose` (`ReactiveOwner`). `own(x)` hands over anything else (a field initializer, an Rx, a `TextEditingController`, a subscription, a timer ...) and returns it; `onDispose(() => ...)` adds a cleanup. `ReactiveOwner.untracked` opts out.
  - Workers (`ever`, `everAll`, `once`, `interval`, `debounce`) listen to the Rx directly: the callback runs synchronously when the value changes (once per `Get.batch`), with no `StreamController` and no microtask. With `onError` / `onDone` they still use the stream.
  - `GetStatus` is `sealed` (`LoadingStatus`, `SuccessStatus`, `ErrorStatus`, `EmptyStatus`), so a `switch` on it must handle every case. Loading and error statuses can carry the last data (`hasData`, `data`, `isRefreshing`, `toLoading()`, `toError()`), like Riverpod's `AsyncValue`; `setLoading`, `setError`, `futurize` and `RxFuture.reload` keep it, and `obx` keeps showing the data while refreshing (`skipLoadingOnRefresh: false` for the old spinner). Breaking: `CustomStatus` / `GetStatus.custom` / `isCustom` / `obx(onCustom:)` are gone, `ErrorStatus<T, S>` is `ErrorStatus<T>` with a non-null `error` and a `stackTrace`, and `status.data` is now a getter on the status (also for carried data).
  - `RxCommand`: an async action as an Rx of its `GetStatus`, with a rule for overlapping calls (`CommandMode.droppable` / `restartable` / `sequential` / `concurrent`), `isRunning`, and `cancel()`. `run()` never throws.
  - Performance: a `Computed` that reads the same sources in the same order as last time matches them by position (no lookup, no new list, no allocation per run), and one that a source notified recomputes without first scanning every source's version. Reading `rx.value` outside an `Obx` is one static check. Measured (release build): a derived sum of 1,000 sources 3.9× faster, a 100-deep chain 1.8×, the diamond 1.7×.
  - Benchmark suite in [`benchmark/`](benchmark/README.md): Fluxy against GetX 4.7.3, upstream GetX 5 at a294d2f, Riverpod 3.5, BLoC 9.2 and Signals 7.1, in release (AOT) macOS builds, with correctness checks (glitches, missed notifications, rebuild counts). Results in [`benchmark/results/RESULTS.md`](benchmark/results/RESULTS.md).
- v0.7.1:
  - `Computed` propagates by marking, then pulling. An Rx write only marks the `Computed`s that read it as stale (and the ones below them as maybe stale), right away and also inside `Get.batch`. Nothing recomputes until a read, or, for a `Computed` with listeners, once the write is fully applied. A `Computed` whose upstream result did not change is not recomputed, and a subscribed `Computed` ignores writes to values it does not read.
  - Listeners of a `Computed` now run after the listeners of the Rx that changed (they could run in the middle of them), still before the write returns. A `Computed` subscribes to its sources as a dependent, not a listener: `rx.listenersLength` no longer counts it; `dependentsLength` and `subscribersLength` are new. Inside `Get.batch`, an Rx nobody listens to is no longer queued.
  - `Obx` and `GetX` track their reads like a `Computed` (matched by position, no hash map for a few values, one `NotifyData` per element instead of one per build). An `Obx` build that throws keeps the values it read before the error, so it still rebuilds when one of them changes.
  - Faster tracked reads: no run stamp for a read in the same order as last time, a lookup index only past 8 sources, versions read from a field (a `Computed` validates before it reports the read), and the notifier's global state in static fields.
  - Measured against v0.7.0 (release build, same machine): batch update 3.4× faster (132 µs, Signals 178 µs), derived sum of 1,000 sources 1.3×, diamond 1.3×, 100-deep chain 1.2×, mount + unmount 1.2×, rebuild-all 1.1×. Fluxy is now fastest in 7 of the 10 scenarios; GetX 4.7.3 stays ahead on wide derived, deep chain and diamond with hand-wired listeners (and glitches), Signals on deep chain.
- v0.7.2:
  - An Rx write compares the new value once (it ran `==` twice, costly for models with lists). An equal value never notifies, the first write included; `update()` that edits in place now notifies on the very first write too, and `trigger()` no longer needs a flag. The unused public `firstRebuild` / `sentToStream` fields are gone.
  - A notifier creates its listener list on the first listener, and a controller its `GetBuilder` id map on the first id. Unsubscribing finds the listener by identity from both ends of the list (it compared closures with `==` from the start: N listeners of one value cost N² compares); `removeListener` with a tear-off made again still works.
  - `Get.find` / `findOrNull` look the key up once (three lookups and three `(Type, tag)` records before).
  - Fix: `dispose()` on a `GetxController`, `Value` or other `ListNotifier` now removes its listeners and sets `isDisposed` (the group mixin's dispose skipped the listener part). `addListener` on a disposed notifier is ignored in release builds (asserts in debug).
  - Benchmark: subscribe + unsubscribe on a shared value, mount + unmount of widgets sharing one value, memory per value and per listener; app sizes (tiny / normal / heavy / super) and the size picker in the benchmark UI.
  - Measured against v0.7.1 (release build, runs alternated): subscribe + unsubscribe 9.5× faster (1.0 ms; GetX 5 9.4 ms), create + dispose 1.8× (fastest of the six), a value with no listener 214 → 180 bytes, batch update 1.1×; other scenarios unchanged. Fluxy is fastest in 5 of the 12 scenarios. Still behind: shared subscribe / unmount (BLoC and Signals ~80 µs / ~1.1 ms with linked subscriptions), wide derived and deep chain (GetX 4, Signals).
- v0.7.3:
  - O(1) unsubscribe: each listener is an entry that knows its index; removing one leaves a hole, compacted once holes are the majority (order kept). Before, `removeAt` shifted every later listener (with a GC write barrier per slot on a long-lived list): 1,000 widgets reading one value spent 2.0 of their 2.2 ms unmount there.
  - `Obx` marks itself dirty right away outside the build phase (a tap, a timer, a stream, an animation tick); only a change made while widgets build still goes through a microtask. A change now shows after one frame instead of a microtask plus a frame.
  - Tracked reads go straight to the running observer's `TrackedSources` (a static field), with the in-order case inlined into the read; a `Computed` read that is already up to date is three field checks, inlined (the try/catch moved to a slow path). `isDisposed` is a field check (no lazily initialized static).
  - Marking: a `Computed` returns itself from `markStale` when the mark is new and one static function passes the mark down (one direct call per level instead of two methods recursing into each other). `Computed`s with listeners are scheduled depth first, a `Computed` before the ones it reaches (it was the other way round); values are glitch-free either way.
  - Measured against v0.7.2 (release build, runs alternated): subscribe + unsubscribe on a shared value 38× faster (26 µs; BLoC / Signals 80 µs), mount + unmount of 1,000 widgets sharing a value 2.9× (1.01 ms), 100-deep chain 1.4× (2.98 ms, now ahead of GetX 4 and Signals), wide derived 1.3×, write and batch 1.2×, diamond 1.1×. Fan-out pays the listener entry (about +0.3 ns per listener call) and stays the fastest. Each listener takes about 30 bytes more (its entry). Fluxy is fastest in 8 of the 12 scenarios and ties on mount + unmount; GetX 4's hand-wired listeners (with glitches) stay ahead on wide derived, diamond and rebuild one.
- v1.0.0: Fluxy names (breaking; no deprecated aliases). The README's "Coming from GetX" lists every rename.
  - The root package is `fluxy` (was `get`): `import 'package:fluxy/fluxy.dart'`; `state_manager.dart`, `route_manager.dart`, `instance_manager.dart` and `utils.dart` keep their paths under `package:fluxy/`.
  - The `Get` object is `Fluxy` (`GetInterface` → `FluxyInterface`); its members keep their names: `Fluxy.to`, `Fluxy.back`, `Fluxy.dialog`, `Fluxy.put`, `Fluxy.find`, `Fluxy.batch`, `Fluxy.locale` … The log name is `FLUXY`.
  - Every `Get…` type is `Fluxy…`: `FluxyController`, `FluxyService`, `FluxyLifeCycleMixin`, `FluxyView`, `FluxyWidget`, `FluxyBuilder`, `FluxyX`, `FluxyStatus` (its cases keep their names), `FluxyListenable`, `FluxyNotifier`, the ticker mixins, `FluxyResponsive…`, `FluxyAnimatedBuilder`, `FluxyPlatform`, `FluxyUtils` and its extensions, `FluxyQueue`, `FluxyMicrotask`; navigation: `FluxyApp` (was `GetMaterialApp`), `FluxyCupertinoApp`, `FluxyPage`, `FluxyMiddleware`, `FluxyDelegate`, `FluxyInformationParser`, `FluxyNavigator`, `FluxyObserver`, `FluxyRouterOutlet`, `FluxySnackBar`, `FluxyHeroScope`, `Fluxy…Route`, `FluxyBackGesture…`.
  - Unchanged: `.obs`, `Rx…`, `Obx`, `ObxValue`, `Computed`, `effect`, `RxFuture`, `RxCommand`, `StateMixin`, `Bindings`, `.tr`.
  - Moving an app: rename the `get:` dependency to `fluxy:`, then `dart run tool/migrate.dart <app>` from a Fluxy checkout (rewrites imports and names; `tool/renames.txt` is the map). Or rewrite the imports and run `dart fix --apply` (`lib/fix_data.yaml`); both give the same result.
  - fluxy_core and fluxy_i18n have their own tests (16 + 16).
- v1.2.0: fluxy_nav rebuilt (plan and results in [NAV-PLAN.md](NAV-PLAN.md)); breaking where it buys correctness. The overlay and page API apps use (`Fluxy.back`, `dialog`, `defaultDialog`, `bottomSheet`, `closeAllDialogs`, `to`, `offAll`, `offAllNamed`, `FluxyApp.router`, `FluxyPage`) is unchanged.
  - Matching: a `RouteTable` (segment trie) built once from the pages. Static segments beat `:param`, which beats `*wildcard`, whatever the registration order (`/settings` no longer opens a `/:id` page registered before it). `:name?` is optional. `Fluxy.to(() => Page())` no longer adds pages to the table.
  - History: an immutable `NavStack` of `NavEntry`s; the duplicate rules are pure functions over it. Every navigation goes through one queue, so the stack changes in call order even when a redirect is asynchronous; with nothing queued it changes before the call returns. `offAll` / `offAllNamed` drop navigations still waiting. A page's future completes when it leaves the stack, with the value it was popped with (also for the back gesture and `Navigator.pop`).
  - Redirects replace `FluxyMiddleware` (removed, no adapter): `FluxyPage(redirect: (request) => ...)` returns null, another address or `NavRequest.stop`; may be async; runs for the page and its children, outer pages first, after `FluxyApp(redirect: ...)`, which also sees the first address and unknown addresses. `FluxyPage(onEnter:, onLeave:)` replace the page-build hooks. An app that sent `/` to a start page with a parser subclass and redirected unknown addresses after a frame needs only `redirect: (r) => r.isUnknown || r.path == '/' ? startRoute() : null`.
  - Nested pages: `FluxyRouterOutlet(parent: '/home', initialRoute:, levels:)` shows the pages of the current address below `parent`; a pop inside it moves the address up a level and the URL follows. `Fluxy.currentRoute` / `previousRoute` / `routing` are the address (nested pages included). `anchorRoute`, `.builder`, `.pickPages` and the generic `RouterOutlet` are gone; `id:` / `Fluxy.nestedKey` stay for independent navigators.
  - `Fluxy.isDialogOpen` / `isBottomSheetOpen` come from a counter kept by the dialog and sheet routes, so an app-provided delegate needs no observer; `closeAllDialogs` and friends only pop popups. The navigator uses `onDidRemovePage`.
  - Removed: `RouteDecoder` (the router configuration is the top entry's `Uri`), `ParseRouteTree`, `FluxyPage.path` / `middlewares` / `unknownRoute`, `FluxyDelegate.activePages` (use `stack`) / `matchRoute` (use `routeTable.match`) / `routingObserver`, `PagesListExt`. `offAll(predicate:)` keeps the page the predicate accepts. `FluxyTestMode` is exported.
  - Measured against v1.0.0 (release build, runs alternated, [benchmark/nav](benchmark/nav/README.md)): matching an address 15× faster (1.25 µs over 152 pages), a deep link (`offAllNamed`) 2×, push + pop 1.13×, pushing onto a 100-deep stack 1.03×, a dialog the same; the frame dominates the last three.
  - Moving an app: replace `FluxyMiddleware` with `redirect:` (an async `redirectDelegate` becomes an async redirect returning the address, null to go on, `NavRequest.stop` instead of returning null), `anchorRoute:` with `parent:`, and drop parser subclasses or `UnknownRoute` pages that redirect, hand-wired `FluxyObserver`s, and imports of `package:fluxy_nav/get_navigation/...`.
  - Files: `lib/src/{routing,router,overlays,app,transitions,facade}`; the facade is one extension per concern (`FluxyNavigationExt`, `ExtensionDialog`, `ExtensionBottomSheet`, `ExtensionSnackbar`, `OverlayExt`, `FluxyAppExt`, `FluxyWindowExt`). Import `package:fluxy_nav/fluxy_nav.dart`; the `get_navigation/` paths are gone.
- v1.3.0: fluxy_nav fixes and clean-ups after the v1.2.0 review (breaking only where noted):
  - Fixed: `toNamed` / `offNamed` / `offAllNamed` / `offNamedUntil` / `offAndToNamed` with `parameters` and a query in the address (`/item/1?a=1`) took the whole address as the path; the parameters now join the query (a parameter replaces a query value of the same name). `Fluxy.to(() => Detail(2))` over a `Detail(1)` opened the same way kept showing `Detail(1)`: a duplicate that builds something else gets a new key. `back(times:)` counts open dialogs and sheets as steps (they used to vanish with the pages under them).
  - Back: system back and `Fluxy.back()` close a dialog or sheet on an outlet's navigator (`useRootNavigator: false`) before a page. A dialog whose `PopScope` refuses system back keeps the page under it (the page used to be popped instead).
  - Browser back / forward, typed URLs and deep links (`setNewRoutePath`): an address already on the stack is gone back to (the entries above it leave, its page keeps its state) instead of moving to the top; other addresses are pushed.
  - An unknown address keeps its address on the not-found page: the URL and `Fluxy.currentRoute` show what was asked for (`/typo`, was `/404`) and its query is in `Fluxy.parameters`.
  - Names: `Fluxy.to` pages are named by `FluxyDelegate.directRouteName` (`/Detail`; generics and `minified:` stripped). Type names change in obfuscated and minified builds, so pass `routeName:` where a URL must stay stable. `FluxyApp(home:)` is at `/` (was `/<HomeWidgetType>`). `offAll(routeName:)` is no longer ignored, and `off` of a page's own type replaces it instead of doing nothing.
  - `FluxyDelegate.topRoute` (the navigator's top route, kept by an observer) backs `Fluxy.rawRoute` / `routing.route`, `back()` and `handlePopupRoutes`, which no longer walk the navigator or assume it's mounted.
  - `NavRequest.stop` is a value that isn't an address (it was `''`); a redirect returning `''` is reported as an error and cancels.
  - Breaking: `IGetNavigation` is `FluxyNavigation` (in `tool/renames.txt` and `lib/fix_data.yaml`); `Fluxy.backLegacy` (use `back`, or `closeAllOverlays` then `back`), `back(canPop:)`, `to(rebuildStack:)` and `FluxyRootState.cleanRouteName` are removed. An unknown `id:` throws a `FlutterError` (was a string). The `GetMiddleware` → `FluxyMiddleware` rename is gone from the migration maps (that type no longer exists; use `redirect:`).
- v1.4.0: fluxy_state dependency injection rebuilt (plan and results in [DI-PLAN.md](DI-PLAN.md)); breaking where it buys correctness. `Fluxy.put` / `lazyPut` / `find` / `delete`, `FluxyController` and its lifecycle, `own()`, `Binding` / `Bind` and page bindings keep their shape.
  - Lifetimes: `put` / `lazyPut` / `spawn` register in the app's root scope and stay until `delete`. They used to be closed when the route where they were first used went away (a popped page, a closed dialog, `offAll` replacing the root page), while code holding them (`final c = Fluxy.put(C())` at the top level) went on using the closed instance. Dependencies in a page's `bindings` / `binds` go into the page's scope and are closed with the page; `DependencyScope(dependencies:, child:)`, `Module` and `RouteReport(dependencies:)` give any subtree a scope. `context.find<T>()` looks from the context's scope outwards; `Fluxy.find` looks in the open scopes, newest first, then the root.
  - Registry rules (`FluxyScope`): a second `put` of a type replaces the first and closes it (it used to be ignored, and the new instance never started); `replace` / `lazyReplace` work for services; `delete` closes the instance, a `lazyPut` keeps its builder (`delete(force: true)` removes it); `reload` closes a `lazyPut` instance so the next `find` builds a new one; `resetInstance` / `Fluxy.reset()` close every instance, newest first (they used to drop them without `onClose`). A missing type throws `DependencyNotFound` (a `FlutterError`, was a string). `put<void>` / `<dynamic>` throws: `void f() => Fluxy.put(C())` infers `void` and used to register under it.
  - Widgets: `FluxyBuilder(init:)`, `FluxyX(init:)` and `Binder` count the widgets sharing an instance they created; it's closed when the last one goes (the first one used to close it under the others). A binder deletes its own registration, never a same-typed one elsewhere. `Bind.create` / `global: false` controllers are local (no longer registered globally) and closed with their widget.
  - New: `Dep<T>` typed handles (`final cart = Dep(() => CartController()); cart()`, `.of(context)`, `.register()` in bindings, `.put`, `.delete`, `.overrideWith`), `Fluxy.overrideWith<T>(fake)` / `clearOverrides()` for tests, `DependencyScope`, `ScopeProvider`, `context.find`.
  - Removed: `SmartManagement` (and `Fluxy.smartManagement`, `FluxyApp(smartManagement:)`), `fenix:` (the builder always stays), `RouterReportManager`, `RouteReportMixin`, `PageRouteReportMixin`, `markAsDirty`, the `key:` parameters of `delete` / `reload`, `Bind.fenixMode`, `resetInstance(clearRouteBindings:)` / `reset(clearRouteBindings:)`.
  - Files: `packages/fluxy_state/lib/src/di/` (scope, facade, dep, widgets, lifecycle, bindings); `lib/get_instance/` is gone.
  - Moving an app: drop `smartManagement:` and `fenix:`; a controller that should go with its page belongs in that page's `bindings` (a `put` in a build method now stays); `Fluxy.put` of an already registered type now replaces it.
- v1.5.0: fluxy_state reactive reads over large collections (from the Hesabak review: report code loops over 5,000-row `RxList`s inside `Obx`), and fluxy_nav fixes from moving Hesabak:
  - The same `Rx` read again right after itself in one `Obx` / `Computed` run (`for (i…) rows[i]`) is dropped with one identity check; it used to leave the positional fast path for a scan of the sources on every read. Other reads cost the same as before (the check runs only after the fast match misses).
  - `RxList` read methods read the list once instead of `length` + `this[i]` per item (two tracked reads each): `isEmpty`, `isNotEmpty`, `first`, `last`, `single`, `elementAt`, `forEach`, `any`, `every`, `contains`, `indexOf`, `lastIndexOf`, `indexWhere`, `lastIndexWhere`, `firstWhere`, `lastWhere`, `singleWhere`, `fold`, `reduce`, `join`, `map`, `expand`, `skip`, `skipWhile`, `take`, `takeWhile`, `getRange`, `sublist`, `toList`, `toSet`. `RxMap`: `values`, `entries`, `length`, `isEmpty`, `isNotEmpty`, `containsKey`, `containsValue`, `forEach`, `map`. Lazy ones (`map`, `skip`…) now iterate the list that was current when called, like `where` already did.
  - Measured against v1.4.0 (release build, runs alternated, [benchmark/nav](benchmark/nav/README.md)): a `Computed` over 5,000 rows recomputes 2.1× faster with `rows[i]`, 2.8× with `fold`, 2.7× with `any` + `firstWhere`; `RxMap.forEach` over 2,000 entries 7×. The main benchmark suite is unchanged (within ±4%).
  - fluxy_nav: `FluxyApp` calls `onReady` after the first frame from a post-frame callback (a `Future` left a zero-length timer, failing widget tests that pump once). A rebuilt `FluxyApp` takes a new `home` (same type: updated in place) and new `theme` / `darkTheme` / `themeMode`; a theme set with `Fluxy.changeTheme` / `changeThemeMode` stays until the app passes a different one. Found moving Hesabak from GetX 4 ([APP-NOTES.md](APP-NOTES.md)).
- Unreleased (v1.6.0), from moving Hesabak and checking NestCut ([APP-NOTES.md](APP-NOTES.md) notes 1-4, 6-12, 14):
  - fluxy_state no longer declares its own `typedef VoidCallback`; it uses `dart:ui`'s, the same type. The duplicate shadowed Flutter's and was an `ambiguous_import` error next to any package doing the same.
  - The rx_edit map helpers (`patch`, `addEntry`, `removeEntryAt`, `removeEntry`) work on any `RxMap<K, V>`, untyped `{}.obs` and int keys included, not only `RxMap<String, V>`.
  - `Fluxy.backToFirst({id})`: closes every dialog and bottom sheet, then goes back to the first page; the form of GetX's `until((route) => route.isFirst)`.
  - `Fluxy.navigator`: the root `NavigatorState`, or `null` when no `FluxyApp` is mounted (`Fluxy.key` still throws there). The top-level `navigator` getter no longer throws without an app either.
  - A rebuilt `FluxyApp` takes a new `locale` / `fallbackLocale` (in the same frame, then one full rebuild for `.tr` in const widgets, as `updateLocale` does); a language set with `Fluxy.updateLocale` stays until the app passes a different one. Translations are not re-read on rebuild.
  - Disposing a `FluxyApp` no longer closes every dependency: `Fluxy.put` / `lazyPut` registrations (the root scope) and translations stay, as in GetX 4, so an app widget unmounted and mounted again finds the controllers it put in `main()`. Its pages' scopes still close with it; `Fluxy.reset()` clears everything, for tests (DI-PLAN D5).
  - `tool/migrate.dart`: before the renames, drops a `refresh()` that follows a write to the same receiver that always notifies (in the same block, up to 5 statements apart when they only save it), turns deep `package:get/<path>` imports into the whole library, and prints a review list (other `refresh()` calls, strings naming GetX). `--keep-refresh` lists instead of dropping; `--material-ui` also rewrites the `flutter/material` / `flutter/cupertino` imports. `actions-runner` folders are skipped.
  - Docs: README "Moving an app that uses flutter/material" (bridge, localizations); fluxy_state README "Changing state" (rows edited in place) and "A report over big lists" (`Computed`).

## Tests

Each package has its own tests in `packages/*/test`; CI (`.github/workflows/main.yml`) runs `flutter analyze` and `flutter test` in every package, so no package can reach outside its listed dependencies. In fluxy_state alone, reset with `Fluxy.resetInstance()`; `Fluxy.reset()` (state and translations) is in fluxy_nav.
