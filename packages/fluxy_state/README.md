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

## Changing state

An Rx notifies when it gets a new value (`value = …`, `list[i] = …`, `add`, `removeWhere`, `map[k] = …` …), never because something inside its old value changed. `refresh()` is `@protected`: there is a public way to say each kind of change.

- **Immutable edits** (maps and lists as rows, JSON documents): `list.patch(i, {'done': true})`, `map.patch(key, {...})`, `map.addEntry(key, v)`, `doc.setIn(['Places', 0, 'Name'], 'x')`, `doc.editListIn(path, (l) => l.add(x))`. Only the edited path is copied; the rest is shared. The map helpers work on any `RxMap<K, V>`, untyped `{}.obs` included.
- **Rows that are mutable objects** edited in place (`item.price = 3`): store the same object back, `items[i] = item`. That notifies, and it is the way to say "this row changed". After an `await`, look the row up again by identity, since rows may have moved:

  ```dart
  item.finalPrice = price;
  final i = items.peek.indexWhere((e) => identical(e, item));
  if (i >= 0) items[i] = item;
  ```

- **Derived values** (a total, a balance shown on another list's cards): read both sources in the `Obx`, or in a `Computed` over both, instead of refreshing one list when the other changes.

### A report over big lists

A summary that scans every row (totals, a ledger) inside `Obx` runs on every rebuild of that widget, including rebuilds caused by something else it reads (a setting). Put the scan in a `Computed`: it recomputes only when a list it read changes, and the `Obx` reads one value.

```dart
class Summary extends FluxyController {
  late final Computed<num> total;

  @override
  void onInit() {
    super.onInit();
    total = Computed(() => sales.fold<num>(0, (s, f) => s + f['Total']));
  }
}

Obx(() => Text('${summary.total.value}  ${settings.currency.value}'));
```

A `Computed` made in `onInit` / `onReady` is disposed with its controller; elsewhere, call `dispose()`.

Depends on: fluxy_core.

Part of [Fluxy](../../FLUXY.md), a fork of GetX (MIT, © Jonny Borges).
