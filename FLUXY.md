# Fluxy

Fluxy is a fork of [GetX](https://github.com/jonataslaw/getx) (from commit `a294d2f`), split into separate packages so each project can depend on only what it needs.

| Package | What it holds | Depends on |
|---|---|---|
| [`fluxy_core`](packages/fluxy_core) | `Get` singleton, logging, engine, `Equality` | — |
| [`fluxy_state`](packages/fluxy_state) | Rx, `Obx`, `Computed`, `RxFuture`, controllers, workers, DI, copy-on-write edits | core |
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
    ref: v0.7.0
```

Only one package (for example state management):

```yaml
fluxy_state:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v0.7.0
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

## Tests

Each package has its own tests in `packages/*/test`; CI (`.github/workflows/main.yml`) runs `flutter analyze` and `flutter test` in every package, so no package can reach outside its listed dependencies. In fluxy_state alone, reset with `Get.resetInstance()`; `Get.reset()` (state and translations) is in fluxy_nav.
