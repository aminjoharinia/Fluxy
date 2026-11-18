# fluxy_nav

Navigation for Fluxy: `FluxyApp` / `FluxyCupertinoApp` (`.router`), `FluxyPage`, `Fluxy.to / toNamed / off / back`, redirects, nested `FluxyRouterOutlet`, transitions, dialogs, bottom sheets and snackbars.

Depends on: fluxy_core, fluxy_state, fluxy_i18n, fluxy_utils.

## Pages and addresses

```dart
FluxyApp.router(
  getPages: [
    FluxyPage(name: '/', page: () => const Home()),
    FluxyPage(name: '/item/:id', page: () => const Item()),
    FluxyPage(name: '/settings', page: () => const Settings()),
  ],
  unknownRoute: FluxyPage(name: '/404', page: () => const NotFound()),
);

Fluxy.toNamed('/item/42?tab=2');   // Fluxy.parameters == {'id': '42', 'tab': '2'}
Fluxy.to(() => const Detail());    // a page outside the table, at /Detail (pass routeName: for a stable URL)
final ok = await Fluxy.toNamed<bool>('/settings'); // Fluxy.back(result: true)
```

- Segments match by priority, whatever the order the pages are listed in: static (`/settings`) before `:param` before `*wildcard`. `:name?` is optional. A trailing slash doesn't matter, case does.
- The history is an immutable `NavStack` (`Fluxy.rootController.rootDelegate.stack`). Navigations run one at a time in call order; with nothing pending, the stack changes before the call returns.
- A page's future completes when it leaves the stack, with the value it was popped with (`Fluxy.back(result:)`, `Navigator.pop(context, value)`, the back gesture); otherwise null.
- An unknown address opens `unknownRoute` but keeps its address (URL, `Fluxy.currentRoute`, query in `Fluxy.parameters`).
- Browser back / forward and deep links: an address already on the stack is gone back to (the entries above it leave); a new one is pushed.
- Same address twice: by default the old entry moves to the top (`preventDuplicateHandlingMode` on the page: `reorderRoutes`, `recreate`, `popUntilOriginalRoute`, `doNothing`; `preventDuplicates: false` pushes a second one).

## Redirects

```dart
FluxyApp.router(
  getPages: pages,
  // Every address, the first one included.
  redirect: (r) => r.isUnknown || r.path == '/' ? startRoute() : null,
);

FluxyPage(
  name: '/admin',
  page: () => const Admin(),
  // Also runs for the children, outer pages first.
  redirect: (r) async => await auth.signedIn() ? null : '/login?then=${r.location}',
  children: [FluxyPage(name: '/users', page: () => const Users())],
);
```

A redirect returns null (go on), another address, or `NavRequest.stop` (cancel; the future completes with null). `NavRequest` has the match (`path`, `parameters`, `isUnknown`), the `arguments` and `isInitial`. `FluxyPage(onEnter:, onLeave:)` are called when the page's entry goes on or leaves the stack.

## Nested pages

```dart
FluxyPage(
  name: '/home',
  participatesInRootNavigator: true,   // the root navigator shows this shell
  page: () => const Scaffold(body: FluxyRouterOutlet(parent: '/home', initialRoute: '/home/feed')),
  children: [
    FluxyPage(name: '/feed', page: () => const Feed()),
    FluxyPage(name: '/post/:id', page: () => const Post()),
  ],
);
```

The outlet shows the pages of the current address below `parent` (all levels, or `levels:`). A pop inside it moves the address up a level and the URL follows. `Fluxy.currentRoute` is the full address. `id:` / `Fluxy.nestedKey` are for independent navigators with their own history.

## Overlays

`Fluxy.dialog`, `defaultDialog`, `generalDialog`, `bottomSheet`, `snackbar` / `rawSnackbar`, `showOverlay`. `Fluxy.back()` and the system back button close a snackbar, then a dialog or sheet (on the root navigator, then on an outlet's), then the page; the last page stays. `back(times: n)` counts each dialog or sheet as a step. `Fluxy.isDialogOpen` / `isBottomSheetOpen` count the open ones on any navigator; `closeAllDialogs` / `closeAllBottomSheets` only pop those.

## Tests

`FluxyTestMode.active = true` with `FluxyTestMode.setTestArguments(...)` / `setTestParameters(...)` gives `Fluxy.arguments` / `Fluxy.parameters` without an app.

Part of [Fluxy](../../FLUXY.md), a fork of GetX (MIT, © Jonny Borges).
