import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fluxy_utils/fluxy_utils.dart';

import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import '../../../src/routing/nav_queue.dart';

/// The router delegate: keeps the navigation history as a [NavStack] and
/// shows it in a [Navigator].
///
/// Every navigation goes through one queue, so the stack changes in call
/// order even when a middleware is asynchronous. A navigation that needs no
/// asynchronous work changes the stack before the call returns.
class FluxyDelegate extends RouterDelegate<RouteDecoder>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<RouteDecoder>,
        IGetNavigation {
  factory FluxyDelegate.createDelegate({
    FluxyPage<dynamic>? notFoundRoute,
    List<FluxyPage> pages = const [],
    List<NavigatorObserver>? navigatorObservers,
    TransitionDelegate<dynamic>? transitionDelegate,
    PopMode backButtonPopMode = PopMode.history,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return FluxyDelegate(
      notFoundRoute: notFoundRoute,
      navigatorObservers: navigatorObservers,
      transitionDelegate: transitionDelegate,
      backButtonPopMode: backButtonPopMode,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
      pages: pages,
      navigatorKey: navigatorKey,
    );
  }

  FluxyDelegate({
    FluxyPage? notFoundRoute,
    this.navigatorObservers,
    this.transitionDelegate,
    this.backButtonPopMode = PopMode.history,
    this.preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
    this.pickPagesForRootNavigator,
    this.restorationScopeId,
    bool showHashOnUrl = true,
    GlobalKey<NavigatorState>? navigatorKey,
    required List<FluxyPage> pages,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
       notFoundRoute = notFoundRoute ??= FluxyPage(
         name: '/404',
         page: () =>
             const Scaffold(body: Center(child: Text('Route not found'))),
       ) {
    // Hash URLs (`/#/Home`) are Flutter's default, so nothing is changed
    // unless path URLs are asked for. That only works before runApp; see
    // setUrlStrategy().
    if (!showHashOnUrl && FluxyPlatform.isWeb) setUrlStrategy();
    addPages([...pages, notFoundRoute]);
    Fluxy.log('FluxyDelegate is created !');
  }

  final PopMode backButtonPopMode;

  /// Not used for pages: each page has its own
  /// [FluxyPage.preventDuplicateHandlingMode].
  final PreventDuplicateHandlingMode preventDuplicateHandlingMode;

  final FluxyPage notFoundRoute;

  final List<NavigatorObserver>? navigatorObservers;

  /// The observer that keeps `Fluxy.routing` (and so `Fluxy.isDialogOpen`,
  /// `Fluxy.isBottomSheetOpen`, `Fluxy.currentRoute`) up to date. `FluxyRoot` sets
  /// it on the root delegate, including one the app passes in, unless the
  /// app already listed a [FluxyObserver] in [navigatorObservers].
  FluxyObserver? routingObserver;

  final TransitionDelegate<dynamic>? transitionDelegate;

  final Iterable<FluxyPage> Function(RouteDecoder currentNavStack)?
  pickPagesForRootNavigator;

  @override
  GlobalKey<NavigatorState> navigatorKey;

  final String? restorationScopeId;

  // ---------------------------------------------------------------------
  // Route table

  final _pages = <FluxyPage>[];
  RouteTable _table = RouteTable(const []);

  /// The registered pages, children flattened to their full paths.
  RouteTable get routeTable => _table;

  List<FluxyPage> get registeredRoutes => _table.routes;

  /// Registers more pages. The table is rebuilt; navigation never changes it.
  void addPages(List<FluxyPage> getPages) {
    _pages.addAll(getPages);
    _table = RouteTable(_pages);
  }

  void clearRouteTree() {
    _pages.clear();
    _table = RouteTable(const []);
  }

  void addPage(FluxyPage getPage) => addPages([getPage]);

  void removePage(FluxyPage getPage) {
    _pages.remove(getPage);
    _table = RouteTable(_pages);
  }

  RouteDecoder matchRoute(String name, {PageSettings? arguments}) {
    final match = _table.match(name);
    return RouteDecoder(
      List.of(match.branch),
      PageSettings(match.uri, arguments?.arguments, match.parameters),
    );
  }

  // ---------------------------------------------------------------------
  // Stack

  NavStack _stack = NavStack();
  final _queue = NavQueue();
  int _epoch = 0;

  /// The navigation history, bottom first.
  NavStack get stack => _stack;

  T arguments<T>() => _stack.top?.arguments as T;

  Map<String, String> get parameters => _stack.top?.match.parameters ?? {};

  PageSettings? get pageSettings => _stack.top?.settings;

  bool get canBack => _stack.canPop;

  /// Puts [next] in place, completes the entries that left it and tells
  /// the router.
  ///
  /// [popped] (the old top) completes with [popResult]; the other entries
  /// that left, and [created] entries that never made it onto the stack,
  /// complete with null. [deferred] is left alone: its route is completing
  /// it with the value it was popped with.
  void _commit(
    NavStack next, {
    NavEntry? popped,
    Object? popResult,
    NavEntry? created,
    NavEntry? deferred,
    bool notify = true,
  }) {
    final previous = _stack;
    _stack = next;
    final kept = {for (final e in next.entries) e.token};
    for (final e in previous.entries) {
      if (kept.contains(e.token) || identical(e.token, deferred?.token)) {
        continue;
      }
      e.complete(identical(e.token, popped?.token) ? popResult : null);
    }
    if (created != null && !kept.contains(created.token)) created.complete();
    if (notify) _notify();
  }

  bool _notifyScheduled = false;

  /// Tells the router, or, while a frame is being built (a navigation
  /// called from a build method), right after that frame.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Runs [change] in the queue, synchronously when it's idle.
  FutureOr<void> _change(void Function() change) => _queue.run<void>(change);

  /// Resolves [target], then applies [apply] to the stack, in the queue.
  ///
  /// With [resets] (offAll, offAllNamed), navigations still waiting for a
  /// middleware are dropped (their futures complete with null).
  FutureOr<NavEntry?> _navigate(
    FutureOr<NavEntry?> Function() target,
    NavStack Function(NavStack stack, NavEntry entry) apply, {
    bool resets = false,
    bool notify = true,
    bool popsTop = false,
    Object? popResult,
  }) {
    if (resets) _epoch++;
    final epoch = _epoch;
    NavEntry? finish(NavEntry? entry) {
      if (entry == null) return null;
      if (epoch != _epoch) {
        entry.complete();
        return null;
      }
      final top = _stack.top;
      _commit(
        apply(_stack, entry),
        created: entry,
        popped: popsTop ? top : null,
        popResult: popResult,
        notify: notify,
      );
      return entry;
    }

    return _queue.run<NavEntry?>(() {
      if (epoch != _epoch) return null;
      final resolved = target();
      if (resolved is Future<NavEntry?>) return resolved.then(finish);
      return finish(resolved);
    });
  }

  /// The future of the entry [navigation] ends up adding.
  Future<T?> _result<T>(FutureOr<NavEntry?> navigation) {
    Future<T?> of(NavEntry? e) =>
        e == null ? Future<T?>.value() : e.result.then((r) => r as T?);
    if (navigation is Future<NavEntry?>) return navigation.then(of);
    return of(navigation);
  }

  // ---------------------------------------------------------------------
  // Resolving addresses

  /// Matches [location] and runs its middlewares. Null when a middleware
  /// stopped the navigation. An unknown address gives the [notFoundRoute]
  /// entry.
  FutureOr<NavEntry?> _resolve<T>(String location, {Object? arguments}) {
    final match = _table.match(location);
    if (match.isUnknown) return _unknownEntry<T>();
    final entry = NavEntry.create<T>(match: match, arguments: arguments);
    if (match.page!.middlewares.isEmpty) return entry;
    return _runMiddlewares<T>(entry);
  }

  NavEntry _unknownEntry<T>() {
    final match = _table.match(notFoundRoute.name);
    return NavEntry.create<T>(
      match: match.isUnknown
          ? RouteMatch.direct(notFoundRoute, Uri.parse(notFoundRoute.name))
          : match,
    );
  }

  NavEntry _directEntry<T>(FluxyPage<T> page, Object? arguments) {
    return NavEntry.create<T>(
      match: RouteMatch.direct(page, Uri.parse(page.name)),
      page: page,
      arguments: arguments,
    );
  }

  Future<NavEntry?> _runMiddlewares<T>(NavEntry entry) async {
    final decoder = RouteDecoder(entry.branch, entry.settings);
    final res = await runMiddleware(decoder);
    if (res == null) return null;
    if (identical(res, decoder) || res == decoder) return entry;
    final location = res.pageSettings?.name ?? res.route?.name;
    if (location == null) return null;
    final match = _table.match(location);
    if (match.isUnknown) return _unknownEntry<T>();
    return NavEntry.create<T>(match: match, arguments: res.args);
  }

  Future<RouteDecoder?> runMiddleware(RouteDecoder config) async {
    final middlewares = config.currentTreeBranch.last.middlewares;
    if (middlewares.isEmpty) {
      return config;
    }
    var iterator = config;
    for (var item in middlewares) {
      var redirectRes = await item.redirectDelegate(iterator);

      if (redirectRes == null) {
        return null;
      }
      if (config != redirectRes) {
        Fluxy.log('Redirect to ${redirectRes.pageSettings?.name}');
      }

      iterator = redirectRes;
      // Stop the iteration over the middleware if we changed page
      // and that redirectRes is not the same as the current config.
      if (config != redirectRes) {
        break;
      }
    }
    // If the target is not the same as the source, we need
    // to run the middlewares for the new route.
    if (iterator != config) {
      return await runMiddleware(iterator);
    }
    return iterator;
  }

  // ---------------------------------------------------------------------
  // Building

  /// The pages the root navigator shows.
  ///
  /// Normally the page of every entry. When the current branch says which
  /// pages take part in the root navigator
  /// ([FluxyPage.participatesInRootNavigator]), only those.
  Iterable<FluxyPage> _rootPages() {
    final top = _stack.top;
    if (top == null) return const [];
    if (pickPagesForRootNavigator != null) {
      return pickPagesForRootNavigator!(currentConfiguration!);
    }
    final branch = top.branch;
    final marked = branch.where((p) => p.participatesInRootNavigator != null);
    if (marked.isEmpty) return _stack.entries.map((e) => e.page);
    return marked.where((p) => p.participatesInRootNavigator == true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _rootPages().toList();
    if (pages.isEmpty) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }
    return FluxyHeroScope(
      child: FluxyNavigator(
        key: navigatorKey,
        onDidRemovePage: _onDidRemovePage,
        pages: pages,
        observers: [?routingObserver, ...?navigatorObservers],
        transitionDelegate:
            transitionDelegate ?? const DefaultTransitionDelegate<dynamic>(),
      ),
    );
  }

  /// The navigator popped a page itself (back gesture, `Navigator.pop`).
  void _onDidRemovePage(Page<Object?> page) {
    _change(() {
      NavEntry? entry;
      for (final e in _stack.entries.reversed) {
        if (e.key == page.key) {
          entry = e;
          break;
        }
      }
      if (entry == null) return;
      if (_stack.length == 1) {
        // The last page stays; the navigator gets it back.
        _notify();
        return;
      }
      _commit(_stack.remove(entry), deferred: entry);
    });
  }

  // ---------------------------------------------------------------------
  // Router

  @override
  RouteDecoder? get currentConfiguration {
    final top = _stack.top;
    if (top == null) return null;
    return RouteDecoder(top.branch, top.settings);
  }

  @override
  Future<void> setNewRoutePath(RouteDecoder configuration) {
    final location = configuration.pageSettings?.name ?? '/';
    final arguments = configuration.args;
    final result = _navigate(
      () => configuration.route == null
          ? _unknownEntry<dynamic>()
          : _resolve<dynamic>(location, arguments: arguments),
      (stack, entry) => stack.add(
        entry,
        mode: entry.page.preventDuplicateHandlingMode,
      ),
    );
    if (result is Future<NavEntry?>) return result;
    return SynchronousFuture<void>(null);
  }

  Future<bool> handlePopupRoutes({Object? result}) async {
    Route? currentRoute;
    navigatorKey.currentState!.popUntil((route) {
      currentRoute = route;
      return true;
    });
    if (currentRoute is PopupRoute) {
      return await navigatorKey.currentState!.maybePop(result);
    }
    return false;
  }

  @override
  Future<bool> popRoute({Object? result, PopMode? popMode}) async {
    //Returning false will cause the entire app to be popped.
    final wasPopup = await handlePopupRoutes(result: result);
    if (wasPopup) return true;

    final mode = popMode ?? backButtonPopMode;
    if (_canPop(mode)) {
      await _pop(mode, result);
      return true;
    }

    return super.popRoute();
  }

  // ---------------------------------------------------------------------
  // Popping

  bool _canPopPage() {
    final top = _stack.top;
    if (top == null) return false;
    return top.branch.length > 1 || _stack.canPop;
  }

  bool _canPop(PopMode mode) => switch (mode) {
    PopMode.history => _stack.canPop,
    PopMode.page => _canPopPage(),
  };

  Future<bool> canPopHistory() => SynchronousFuture(_stack.canPop);

  Future<bool> canPopPage() => SynchronousFuture(_canPopPage());

  FutureOr<void> _pop(PopMode mode, Object? result) => switch (mode) {
    PopMode.history => _popHistory(result),
    PopMode.page => _popPage(result),
  };

  FutureOr<void> _popHistory(Object? result) => _change(() {
    if (!_stack.canPop) return;
    _commit(_stack.pop(), popped: _stack.top, popResult: result);
  });

  /// Pops one level of the current branch: `/home/products/1` becomes
  /// `/home/products`. When the entry below is that page, the entry is
  /// popped; otherwise it's replaced.
  FutureOr<void> _popPage(Object? result) => _change(() {
    final top = _stack.top;
    if (top == null) return;
    final branch = top.branch;
    if (branch.length < 2) {
      if (_stack.canPop) {
        _commit(_stack.pop(), popped: top, popResult: result);
      }
      return;
    }
    final parent = branch[branch.length - 2].name;
    if (_stack.below?.name == parent) {
      _commit(_stack.pop(), popped: top, popResult: result);
      return;
    }
    final entry = NavEntry.create<dynamic>(match: _table.match(parent));
    _commit(_stack.replaceTop(entry), popped: top, popResult: result);
  });

  Future<T?> popHistory<T>(T result) async {
    await _popHistory(result);
    return null;
  }

  @override
  void back<T>([T? result]) {
    _popHistory(result);
  }

  @override
  void backUntil(bool Function(FluxyPage) predicate) {
    _change(() => _commit(_stack.popUntil((e) => predicate(e.page))));
  }

  /// Removes routes according to [PopMode]
  /// until it reaches the specific [fullRoute],
  /// DOES NOT remove the [fullRoute]
  @override
  Future<void> popModeUntil(
    String fullRoute, {
    PopMode popMode = PopMode.history,
  }) async {
    while (_canPop(popMode)) {
      final top = _stack.top!;
      if (top.location == fullRoute || top.name == fullRoute) break;
      await _pop(popMode, null);
    }
  }

  @override
  void removeRoute<T>(String name) {
    _change(() {
      if (_stack.length < 2) return;
      NavEntry? entry;
      for (final e in _stack.entries.reversed) {
        if (e.location == name || e.name == name) {
          entry = e;
          break;
        }
      }
      if (entry != null) _commit(_stack.remove(entry));
    });
  }

  // ---------------------------------------------------------------------
  // Navigation

  @override
  Future<void> goToUnknownPage([bool clearPages = false]) async {
    await _navigate(
      _unknownEntry<dynamic>,
      (stack, entry) => clearPages
          ? NavStack([entry])
          : stack.add(entry, mode: entry.page.preventDuplicateHandlingMode),
      resets: clearPages,
    );
  }

  @override
  Future<T?> toNamed<T>(
    String page, {
    dynamic arguments,
    dynamic id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    return _result<T>(
      _navigate(
        () => _resolve<T>(page, arguments: arguments),
        (stack, entry) => stack.add(
          entry,
          preventDuplicates: preventDuplicates,
          mode: entry.page.preventDuplicateHandlingMode,
        ),
      ),
    );
  }

  FluxyPage<T> _pageFor<T>(
    Widget Function() page, {
    required String routeName,
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    bool fullscreenDialog = false,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) {
    return FluxyPage<T>(
      name: routeName,
      opaque: opaque ?? true,
      page: page,
      gestureWidth: gestureWidth,
      showCupertinoParallax: showCupertinoParallax,
      popGesture: popGesture ?? Fluxy.defaultPopGesture,
      transition: transition ?? Fluxy.defaultTransition,
      curve: curve ?? Fluxy.defaultTransitionCurve,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      transitionDuration: duration ?? Fluxy.defaultTransitionDuration,
      preventDuplicates: preventDuplicates,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
    );
  }

  @override
  Future<T?> to<T>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    String? id,
    String? routeName,
    bool fullscreenDialog = false,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
    bool rebuildStack = true,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) {
    final getPage = _pageFor<T>(
      page,
      routeName: routeName ?? _cleanRouteName("/${page.runtimeType}"),
      opaque: opaque,
      transition: transition,
      curve: curve,
      duration: duration,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      preventDuplicates: preventDuplicates,
      popGesture: popGesture,
      showCupertinoParallax: showCupertinoParallax,
      gestureWidth: gestureWidth,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
    );
    return _result<T>(
      _navigate(
        () => _directEntry<T>(getPage, arguments),
        (stack, entry) => stack.add(
          entry,
          preventDuplicates: preventDuplicates,
          mode: preventDuplicateHandlingMode,
        ),
        notify: rebuildStack,
      ),
    );
  }

  @override
  Future<T?> off<T>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    String? id,
    String? routeName,
    bool fullscreenDialog = false,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
  }) {
    final getPage = _pageFor<T>(
      page,
      routeName: routeName ?? _cleanRouteName("/${page.runtimeType}"),
      opaque: opaque,
      transition: transition,
      curve: curve,
      duration: duration,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      popGesture: popGesture,
      showCupertinoParallax: showCupertinoParallax,
      gestureWidth: gestureWidth,
    );
    return _result<T>(
      _navigate(
        () => _directEntry<T>(getPage, arguments),
        (stack, entry) => stack.replaceTop(entry),
      ),
    );
  }

  /// Removes the entries above the topmost one [predicate] accepts (all of
  /// them when none does), then adds the page.
  @override
  Future<T?>? offAll<T>(
    Widget Function() page, {
    bool Function(FluxyPage route)? predicate,
    bool opaque = true,
    bool? popGesture,
    String? id,
    String? routeName,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool fullscreenDialog = false,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
  }) {
    final getPage = _pageFor<T>(
      page,
      routeName: routeName ?? _cleanRouteName("/${page.runtimeType}"),
      opaque: opaque,
      transition: transition,
      curve: curve,
      duration: duration,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      popGesture: popGesture,
      showCupertinoParallax: showCupertinoParallax,
      gestureWidth: gestureWidth,
    );
    return _result<T>(
      _navigate(
        () => _directEntry<T>(getPage, arguments),
        (stack, entry) => predicate == null
            ? NavStack([entry])
            : stack.removeUntil((e) => predicate(e.page)).push(entry),
        resets: true,
      ),
    );
  }

  @override
  Future<T?>? offAllNamed<T>(
    String newRouteName, {
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) {
    return _result<T>(
      _navigate(
        () => _resolve<T>(newRouteName, arguments: arguments),
        (stack, entry) => NavStack([entry]),
        resets: true,
      ),
    );
  }

  @override
  Future<T?>? offNamedUntil<T>(
    String page, {
    bool Function(FluxyPage route)? predicate,
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) {
    return _result<T>(
      _navigate(
        () => _resolve<T>(page, arguments: arguments),
        (stack, entry) => stack
            .popUntil((e) => predicate?.call(e.page) ?? false)
            .add(entry, mode: entry.page.preventDuplicateHandlingMode),
      ),
    );
  }

  @override
  Future<T?> offNamed<T>(
    String page, {
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) {
    return _result<T>(
      _navigate(
        () => _resolve<T>(page, arguments: arguments),
        (stack, entry) => stack.replaceTop(entry),
      ),
    );
  }

  @override
  Future<T?> toNamedAndOffUntil<T>(
    String page,
    bool Function(FluxyPage) predicate, [
    Object? data,
  ]) {
    return _result<T>(
      _navigate(
        () => _resolve<T>(page, arguments: data),
        (stack, entry) => stack
            .removeUntil((e) => predicate(e.page))
            .add(entry, mode: entry.page.preventDuplicateHandlingMode),
      ),
    );
  }

  @override
  Future<T?> offUntil<T>(
    Widget Function() page,
    bool Function(FluxyPage) predicate, [
    Object? arguments,
  ]) {
    final getPage = _pageFor<T>(
      page,
      routeName: _cleanRouteName("/${page.runtimeType}"),
    );
    return _result<T>(
      _navigate(
        () => _directEntry<T>(getPage, arguments),
        (stack, entry) => stack
            .removeUntil((e) => predicate(e.page))
            .add(entry, mode: getPage.preventDuplicateHandlingMode),
      ),
    );
  }

  @override
  Future<R?> backAndtoNamed<T, R>(
    String page, {
    T? result,
    Object? arguments,
  }) {
    return _result<R>(
      _navigate(
        () => _resolve<R>(page, arguments: arguments),
        (stack, entry) => NavStack(
          stack.entries.take(stack.isEmpty ? 0 : stack.length - 1),
        ).add(entry, mode: entry.page.preventDuplicateHandlingMode),
        popsTop: true,
        popResult: result,
      ),
    );
  }

  /// Takes a route [name] String generated by [to], [off], [offAll]
  /// (and similar context navigation methods), cleans the extra chars and
  /// accommodates the format.
  /// `() => MyHomeScreenView` becomes `/MyHomeScreenView`.
  String _cleanRouteName(String name) {
    name = name.replaceAll('() => ', '');
    if (!name.startsWith('/')) {
      name = '/$name';
    }
    return Uri.tryParse(name)?.toString() ?? name;
  }
}
