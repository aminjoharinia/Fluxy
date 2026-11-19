# Fluxy

Fluxy is a private fork of [GetX](https://github.com/jonataslaw/getx) (MIT), split into small packages and fixed where GetX 5 broke. Each project depends on only the packages it uses.

| Package | What it holds |
|---|---|
| `fluxy_core` | `Fluxy` object, logging, `Fluxy.asap`, `Equality` |
| `fluxy_state` | `.obs` / `Rx*`, `Obx`, glitch-free `Computed`, `effect`, `RxFuture`, `RxCommand`, controllers, workers, DI, `Fluxy.batch`, `peek`, copy-on-write edits |
| `fluxy_i18n` | `Translations`, reactive `.tr`, `.trParams`, locale state |
| `fluxy_utils` | `FluxyPlatform`, validators, extensions, `FluxyQueue` |
| `fluxy_nav` | `FluxyApp` / `FluxyCupertinoApp`, router, `Fluxy.to` / `back`, dialogs, sheets, snackbars |
| `fluxy_ui` | responsive views, `hp` / `wp`, animation extensions |

The root package `fluxy` re-exports everything: `import 'package:fluxy/fluxy.dart'`. Up to v0.7.3 it was named `get` and used GetX's names; see [Coming from GetX](#coming-from-getx).

## Install

```yaml
dependencies:
  fluxy:                   # everything
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v1.6.0
  # or one package:
  fluxy_state:
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v1.6.0
      path: packages/fluxy_state
```

## Quick tour

```dart
class CartController extends FluxyController {
  final items = <Map<String, dynamic>>[].obs;
  final total = 0.0.obs;

  void add(Map<String, dynamic> item) => Fluxy.batch(() {
        items.add(item);                       // one notification each,
        total.value += item['price'] as double; // listeners see both at once
      });
}

final cart = Fluxy.put(CartController());

Obx(() => Text('${cart.items.length} items, ${'total'.tr}: ${cart.total}'));
```

- **State:** an `Obx` subscribes to exactly the Rx values its last build read. `Computed` derives values without glitches, `effect` reacts to them, and effects, `Computed`s and workers made in a controller's `onInit` are disposed with it. Write new values instead of editing in place (`mapWith`, `listWith`, `setIn`, `patch`); `rx.peek` reads without subscribing.
- **Navigation:** `FluxyApp.router(getPages: ..., redirect: ...)`. Pages match by segment (static before `:param` before `*`), navigations apply in call order, and `redirect` (on the app and on each page, async allowed) decides where an address goes, the first one included. `FluxyRouterOutlet(parent: ...)` shows nested pages. Web uses hash URLs unless you call `setUrlStrategy()` before `runApp`. More in [packages/fluxy_nav](packages/fluxy_nav/README.md).
- **Dependencies:** `Fluxy.put` / `lazyPut` live until `delete`; a page's `bindings` (or a `DependencyScope`) give dependencies the page's lifetime. `Dep(() => C())` is a typed handle, `Fluxy.overrideWith` swaps one in tests. More in [packages/fluxy_state](packages/fluxy_state/README.md).
- **Translations:** `.tr` inside an `Obx` updates on a language change; `Fluxy.updateLocale(locale)` rebuilds the rest.

## Coming from GetX

Fluxy keeps GetX's API under its own names (no deprecated aliases): every `Get` prefix became `Fluxy`. Member names did not change (`Fluxy.to`, `Fluxy.back`, `Fluxy.put`, `getPages:` …), nor did the short idioms: `.obs`, `Rx…`, `Obx`, `ObxValue`, `StateMixin`, `.tr`, `Bindings`, the `FluxyStatus` cases (`LoadingStatus`, `SuccessStatus`, `ErrorStatus`, `EmptyStatus`).

To move an app: in `pubspec.yaml`, rename the `get:` dependency to `fluxy:`, then run the codemod from a Fluxy checkout (`dart run tool/migrate.dart <app>`, see [tool/README.md](tool/README.md)). Or rewrite the imports (`package:get/` → `package:fluxy/`) and run `dart fix --apply`: the root package ships the type renames in `lib/fix_data.yaml`. The codemod also drops `refresh()` calls that follow a write that already notifies (`refresh()` is `@protected` in Fluxy), fixes deep `package:get/<path>` imports, and lists what to review: the other `refresh()` calls and strings that still name GetX.

Behaviour to know: as in GetX 4, `Fluxy.put` / `lazyPut` and translations registered in `main()` survive the `FluxyApp` being disposed and mounted again (since v1.6.0); only a page's own `bindings` close with it. `Fluxy.reset()` clears everything, for tests.

| GetX | Fluxy |
|---|---|
| `package:get/get.dart` (package `get`) | `package:fluxy/fluxy.dart` (package `fluxy`) |
| `Get` (`Get.to`, `Get.find`, …) | `Fluxy` (`Fluxy.to`, `Fluxy.find`, …) |
| `GetInterface` | `FluxyInterface` |
| `GetMaterialApp` | `FluxyApp` |
| `GetCupertinoApp` | `FluxyCupertinoApp` |
| `GetPage` | `FluxyPage` |
| `GetPageBuilder` | `FluxyPageBuilder` |
| `GetRouteAwarePageBuilder` | `FluxyRouteAwarePageBuilder` |
| `GetMiddleware` | `FluxyPage(redirect:)` / `FluxyApp(redirect:)` (`FluxyMiddleware` until v1.2.0) |
| `GetDelegate` | `FluxyDelegate` |
| `GetInformationParser` | `FluxyInformationParser` |
| `GetNavigator` | `FluxyNavigator` |
| `GetObserver` | `FluxyObserver` |
| `GetRouterOutlet` | `FluxyRouterOutlet` (`parent:` instead of `anchorRoute:` since v1.2.0) |
| `IGetNavigation` | `FluxyNavigation` (since v1.3.0) |
| `SmartManagement`, `Get.smartManagement` | removed in v1.4.0: `put` / `lazyPut` live until `delete`; page `bindings` / `DependencyScope` give a page's lifetime |
| `lazyPut(fenix: true)` | `lazyPut` (the builder always stays after `delete` since v1.4.0) |
| `RouterReportManager`, `RouteReportMixin` | page scopes (v1.4.0); `RouteReport(dependencies:)` / `DependencyScope` |
| `GetPageRoute` | `FluxyPageRoute` |
| `GetModalBottomSheetRoute` | `FluxyModalBottomSheetRoute` |
| `GetPageRouteTransitionMixin` | `FluxyPageRouteTransitionMixin` |
| `GetSnackBar` | `FluxySnackBar` |
| `GetSnackBarState` | `FluxySnackBarState` |
| `GetHeroScope` | `FluxyHeroScope` |
| `GetBackGestureController` | `FluxyBackGestureController` |
| `GetBackGestureDetector` | `FluxyBackGestureDetector` |
| `GetBackGestureDetectorState` | `FluxyBackGestureDetectorState` |
| `GetNavigationExt` | `FluxyNavigationExt` |
| `GetResetExt` | `FluxyResetExt` |
| `GetxController` | `FluxyController` |
| `GetxService` | `FluxyService` |
| `GetxServiceMixin` | `FluxyServiceMixin` |
| `GetLifeCycleMixin` | `FluxyLifeCycleMixin` |
| `GetView` | `FluxyView` |
| `GetWidget` | `FluxyWidget` |
| `GetBuilder` | `FluxyBuilder` |
| `GetControllerBuilder` | `FluxyControllerBuilder` |
| `GetX` | `FluxyX` |
| `GetXState` | `FluxyXState` |
| `GetXControllerBuilder` | `FluxyXControllerBuilder` |
| `GetStatus` | `FluxyStatus` |
| `GetListenable` | `FluxyListenable` |
| `GetNotifier` | `FluxyNotifier` |
| `GetTickerProviderStateMixin` | `FluxyTickerProviderStateMixin` |
| `GetSingleTickerProviderStateMixin` | `FluxySingleTickerProviderStateMixin` |
| `GetReactiveExt` | `FluxyReactiveExt` |
| `GetResponsiveView` | `FluxyResponsiveView` |
| `GetResponsiveWidget` | `FluxyResponsiveWidget` |
| `GetResponsiveMixin` | `FluxyResponsiveMixin` |
| `GetAnimatedBuilder` | `FluxyAnimatedBuilder` |
| `GetAnimatedBuilderState` | `FluxyAnimatedBuilderState` |
| `GetPlatform` | `FluxyPlatform` |
| `GetUtils` | `FluxyUtils` |
| `GetStringUtils` | `FluxyStringUtils` |
| `GetNumUtils` | `FluxyNumUtils` |
| `GetDurationUtils` | `FluxyDurationUtils` |
| `GetDynamicUtils` | `FluxyDynamicUtils` |
| `GetQueue` | `FluxyQueue` |
| `GetQueueCancelledException` | `FluxyQueueCancelledException` |
| `GetMicrotask` | `FluxyMicrotask` |
| `Get.until((route) => route.isFirst)` | `Fluxy.backToFirst()` (closes dialogs and sheets too; since v1.6.0) |
| `Get.key.currentState` (null without an app) | `Fluxy.navigator` (null without an app; `Fluxy.key` throws there; since v1.6.0) |

### Moving an app that uses flutter/material

Fluxy is built on `material_ui` / `cupertino_ui`, so `FluxyApp(theme:, themeMode:)` take their types, and an app importing `package:flutter/material.dart` gets `ThemeData` / `ThemeMode` type errors. Moving Hesabak took these steps:

1. Add `material_ui` and `cupertino_ui` to `pubspec.yaml`, and rewrite the imports: `dart run tool/migrate.dart <app> --material-ui` turns `package:flutter/material.dart` into `package:material_ui/material_ui.dart` and `flutter/cupertino` into `cupertino_ui`.
2. Packages still on `flutter/material` (date pickers, `printing`, `intl_phone_field`, `flutter_slidable` …) read `flutter/material`'s `Theme`. Wrap the app in `MaterialUiCompatibilityBridge` (deprecated, but the official bridge) in `FluxyApp(builder:)`, so they get the app's colours and fonts, dark mode included:

   ```dart
   builder: (context, child) =>
       // ignore: deprecated_member_use
       MaterialUiCompatibilityBridge(delegates: const [], child: child!),
   ```

3. Localizations: keep those packages' delegates as `flutter/material` ones (for example `PersianMaterialLocalizations.delegate`, and `DefaultMaterialLocalizations.delegate` imported `as legacy` from `flutter/material`), and add `material_ui`'s `GlobalMaterialLocalizations.delegate` and `cupertino_ui`'s `GlobalCupertinoLocalizations.delegate` for the app's own widgets.
4. Code that hands `MaterialLocalizations` to such a package imports that type from `flutter/material`.

Remove the bridge once those packages move to `material_ui`.

What changed from GetX, release by release: [FLUXY.md](FLUXY.md). Working apps: [`example/`](example/) (bindings, `StateController` with `obx`, translations, snackbars) and [`example_nav2/`](example_nav2/) (nested routes, redirects). GetX's guides and changelog are gone from this repo (they used GetX's names and `GetConnect`); they stay in the tag `v0.0.0-upstream-a294d2f`.

How Fluxy compares with GetX 4, upstream GetX 5, Riverpod, BLoC and Signals in release builds: [benchmark/results/RESULTS.md](benchmark/results/RESULTS.md) (method in [benchmark/README.md](benchmark/README.md)).
