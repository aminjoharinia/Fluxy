# Fluxy navigation example

Nested navigation with Fluxy's router (Navigator 2.0 under `FluxyApp`):

- a root page with a drawer and a `FluxyRouterOutlet` for the nested pages (`lib/app/modules/root`)
- `/home` with its own outlet for dashboard / products / product details / profile
- `ensureAuth` and `ensureNotAuthed` page redirects sending through `/login?then=…` (`lib/app/redirects`)
- one `Binding` per page and a global `AuthService` from `FluxyApp(binds: …)`

```bash
flutter run -d chrome   # the address bar follows the nested routes
flutter test
```

`example/` next to this folder shows controllers with `obx`, translations and snackbars.
