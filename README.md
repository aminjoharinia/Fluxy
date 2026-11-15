# Fluxy

Fluxy is a private fork of [GetX](https://github.com/jonataslaw/getx) (MIT), split into small packages and fixed where GetX 5 broke. Each project depends on only the packages it uses.

| Package | What it holds |
|---|---|
| `fluxy_core` | `Get` singleton, logging, `Get.asap`, `Equality` |
| `fluxy_state` | `.obs` / `Rx*`, `Obx`, controllers, workers, DI, `Get.batch`, `peek`, copy-on-write edits |
| `fluxy_i18n` | `Translations`, reactive `.tr`, `.trParams`, locale state |
| `fluxy_utils` | `GetPlatform`, validators, extensions, `GetQueue` |
| `fluxy_nav` | `GetMaterialApp` / `GetCupertinoApp`, router, `Get.to` / `back`, dialogs, sheets, snackbars |
| `fluxy_ui` | responsive views, `hp` / `wp`, animation extensions |

The root package is still named `get` and re-exports everything, so `import 'package:get/get.dart'` code works unchanged.

## Install

```yaml
dependencies:
  get:                     # everything
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v0.5.0
  # or one package:
  fluxy_state:
    git:
      url: https://github.com/aminjoharinia/Fluxy.git
      ref: v0.5.0
      path: packages/fluxy_state
```

## Quick tour

```dart
class CartController extends GetxController {
  final items = <Map<String, dynamic>>[].obs;
  final total = 0.0.obs;

  void add(Map<String, dynamic> item) => Get.batch(() {
        items.add(item);                       // one notification each,
        total.value += item['price'] as double; // listeners see both at once
      });
}

final cart = Get.put(CartController());

Obx(() => Text('${cart.items.length} items, ${'total'.tr}: ${cart.total}'));
```

- **State:** an `Obx` subscribes to exactly the Rx values its last build read. Write new values instead of editing in place (`mapWith`, `listWith`, `setIn`, `patch`); `rx.peek` reads without subscribing.
- **Navigation:** `GetMaterialApp.router(getPages: ..., initialRoute: ..., unknownRoute: ...)`. Unknown addresses reach `unknownRoute`; web uses hash URLs unless you call `setUrlStrategy()` before `runApp`.
- **Translations:** `.tr` inside an `Obx` updates on a language change; `Get.updateLocale(locale)` rebuilds the rest.

What changed from GetX, release by release: [FLUXY.md](FLUXY.md). The upstream GetX guides in [`documentation/`](documentation/) still describe most of the API, but not the changes listed there (and they mention `GetConnect`, which is removed).
