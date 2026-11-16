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

The root package `fluxy` re-exports everything: `import 'package:fluxy/fluxy.dart'`. It was named `get` until v0.8.0; `dart run tool/migrate.dart <app>` rewrites the imports (see `tool/README.md`).

## Install

```yaml
dependencies:
  fluxy:                   # everything
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v0.7.3
  # or one package:
  fluxy_state:
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v0.7.3
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
- **Navigation:** `FluxyApp.router(getPages: ..., initialRoute: ..., unknownRoute: ...)`. Unknown addresses reach `unknownRoute`; web uses hash URLs unless you call `setUrlStrategy()` before `runApp`.
- **Translations:** `.tr` inside an `Obx` updates on a language change; `Fluxy.updateLocale(locale)` rebuilds the rest.

What changed from GetX, release by release: [FLUXY.md](FLUXY.md). The upstream GetX guides in [`documentation/`](documentation/) still describe most of the API, but not the changes listed there (and they mention `GetConnect`, which is removed).

How Fluxy compares with GetX 4, upstream GetX 5, Riverpod, BLoC and Signals in release builds: [benchmark/results/RESULTS.md](benchmark/results/RESULTS.md) (method in [benchmark/README.md](benchmark/README.md)).
