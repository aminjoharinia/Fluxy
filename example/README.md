# Fluxy example

A small app showing the everyday Fluxy pieces together:

- `FluxyApp` with named routes, nested pages and a `Binding` per page (`lib/routes`, `lib/pages/home/bindings`)
- a `StateController` loaded with `futurize` and shown with `controller.obx(...)` (loading / success / error)
- `Fluxy.toNamed` with arguments, `Fluxy.snackbar`, `.tr` translations and `Fluxy.updateLocale` (en_US / pt_BR)

The data is offline sample data (`lib/pages/home/data/home_api_provider.dart`); Fluxy has no HTTP client.

```bash
flutter run      # pick a device
flutter test     # controller tests with mock repositories
```

`example_nav2/` next to this folder shows nested navigation with `FluxyRouterOutlet`, middleware and a drawer.
