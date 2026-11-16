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
    ref: v0.6.2
```

Only one package (for example state management):

```yaml
fluxy_state:
  git:
    url: https://github.com/aminjoharinia/Fluxy.git
    ref: v0.6.2
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

## Tests

Each package has its own tests in `packages/*/test`; CI (`.github/workflows/main.yml`) runs `flutter analyze` and `flutter test` in every package, so no package can reach outside its listed dependencies. In fluxy_state alone, reset with `Get.resetInstance()`; `Get.reset()` (state and translations) is in fluxy_nav.
