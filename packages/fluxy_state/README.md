# fluxy_state

State management: `.obs` / `Rx*`, `RxList/Map/Set`, `Obx`, `FluxyX<T>`, `FluxyBuilder`, `FluxyController`, `StateMixin`, workers (`ever`, `debounce` ...) and dependency injection (`Fluxy.put / find / lazyPut`, scopes, `Dep<T>` handles, bindings).

## Dependencies

```dart
final places = Fluxy.put(PlacesController()); // lives until Fluxy.delete
Fluxy.lazyPut(() => Api());                     // built on the first find, kept
final api = Fluxy.find<Api>();

final cart = Dep(() => CartController());       // a typed handle: its own key
cart().add(item);                               // built on first use, kept
```

- `put` / `lazyPut` / `spawn` register in the app's root scope and stay there until `delete`, whatever page or dialog they were first used in. A second `put` of the same type replaces the first (which is closed); a second `lazyPut` is ignored.
- `delete` closes the instance (`onClose`, owned workers disposed). A `lazyPut` keeps its builder, so the next `find` builds a new one; `delete(force: true)` removes the registration. `permanent: true` instances and `FluxyService`s need `force`.
- **Page lifetimes:** dependencies registered in a page's `bindings` (or `binds`) go into the page's scope and are closed when the page goes. `DependencyScope(dependencies: ..., child: ...)` does the same for any subtree; `context.find<T>()` looks from the context's scope outwards. `Fluxy.find` looks in the open scopes, newest first, then the root.
- `FluxyBuilder<T>(init:)` / `FluxyX<T>(init:)` / `Binder` count the widgets sharing an instance they created; it's closed when the last one goes.
- `Dep<T>`: `handle()` (root, lazily), `handle.of(context)`, `handle.register()` in bindings for a page-own instance, `handle.put(x)`, `handle.delete()`.
- Tests: `Fluxy.overrideWith<Api>(FakeApi())` / `handle.overrideWith(fake)` win over registrations until `Fluxy.clearOverrides()` or `Fluxy.resetInstance()`, which closes every instance, newest first.
- `Fluxy.put<void>` / `<dynamic>` throws: `void f() => Fluxy.put(C())` infers `void`.

Depends on: fluxy_core.

Part of [Fluxy](../../FLUXY.md), a fork of GetX (MIT, © Jonny Borges).
