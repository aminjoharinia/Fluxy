import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fluxy_utils/fluxy_utils.dart';

import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import '../routing/nav_queue.dart';

/// The router delegate: keeps the navigation history as a [NavStack] and
/// shows it in a [Navigator].
///
/// Every navigation goes through one queue, so the stack changes in call
/// order even when a redirect is asynchronous. A navigation that needs no
/// asynchronous work changes the stack before the call returns.
///
/// The router configuration is the address (`Uri`) of the top entry.
class FluxyDelegate extends RouterDelegate<Uri>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<Uri>,
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
    FluxyRedirect? redirect,
  }) {
    return FluxyDelegate(
      redirect: redirect,
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
    this.redirect,
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

  /// Runs before every navigation to an address, the first one (the
  /// address the app opens at) included, ahead of the pages' own
  /// [FluxyPage.redirect]. Not run for `Fluxy.to(() => Page())` pages.
  ///
  /// `FluxyApp(redirect: ...)` sets it, also on a delegate the app passed
  /// in, unless that one has its own.
  FluxyRedirect? redirect;

  /// Not used for pages: each page has its own
  /// [FluxyPage.preventDuplicateHandlingMode].
  final PreventDuplicateHandlingMode preventDuplicateHandlingMode;

  final FluxyPage notFoundRoute;

  final List<NavigatorObserver>? navigatorObservers;

  /// Logs page changes and tells route-bound dependencies when their page
  /// goes away. Always on; apps don't need to add an observer.
  final _reports = FluxyObserver();

  final TransitionDelegate<dynamic>? transitionDelegate;

  /// Picks the root navigator's pages from the stack, instead of the
  /// default (see [FluxyPage.participatesInRootNavigator]).
  final Iterable<FluxyPage> Function(NavStack stack)?
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

  bool _wasBack = false;
  String _removed = '';

  /// Where the app is, read from the stack and the open overlays.
  ///
  /// `current` is the path of the top page (inside nested pages too),
  /// `previous` the one under it, `args` the top page's arguments.
  Routing get routing {
    final top = _stack.top;
    Route<dynamic>? route;
    navigatorKey.currentState?.popUntil((r) {
      route = r;
      return true;
    });
    return Routing(
      current: top?.name ?? '',
      previous: _stack.below?.name ?? '',
      args: top?.arguments,
      removed: _removed,
      route: route,
      isBack: _wasBack,
      isDialog: FluxyOverlays.dialogs > 0,
      isBottomSheet: FluxyOverlays.bottomSheets > 0,
    );
  }

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
    final before = {for (final e in previous.entries) e.token};
    _wasBack =
        previous.top != null &&
        !kept.contains(previous.top!.token) &&
        next.top != null &&
        before.contains(next.top!.token);
    _removed = '';
    for (final e in previous.entries) {
      if (kept.contains(e.token)) continue;
      if (!identical(e, previous.top)) _removed = e.name;
      if (identical(e.token, deferred?.token)) continue;
      e.complete(identical(e.token, popped?.token) ? popResult : null);
    }
    if (created != null && !kept.contains(created.token)) created.complete();
    for (final e in previous.entries) {
      if (!kept.contains(e.token)) _call(e.page.onLeave, e);
    }
    for (final e in next.entries) {
      if (!before.contains(e.token)) _call(e.page.onEnter, e);
    }
    if (notify) _notify();
  }

  void _call(FluxyPageCallback? callback, NavEntry entry) {
    if (callback == null) return;
    try {
      callback(entry.match);
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: s,
        library: 'fluxy_nav',
        context: ErrorDescription('while calling onEnter / onLeave of ${entry.location}'),
      ));
    }
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
  /// redirect are dropped (their futures complete with null).
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

  /// Matches [location] and runs the redirects: the app's [redirect],
  /// then the matched page's and its parents' ([RouteMatch.redirects]).
  /// Null when a redirect stopped the navigation. An unknown address no
  /// redirect sends elsewhere gives the [notFoundRoute] entry.
  FutureOr<NavEntry?> _resolve<T>(
    String location, {
    Object? arguments,
    int hops = 0,
  }) {
    final match = _table.match(location);
    final request = NavRequest(
      match,
      arguments: arguments,
      from: _stack.top?.location,
    );
    final redirects = [?redirect, ...match.redirects];
    return _runRedirects<T>(request, redirects, 0, hops);
  }

  FutureOr<NavEntry?> _runRedirects<T>(
    NavRequest request,
    List<FluxyRedirect> redirects,
    int index,
    int hops,
  ) {
    for (var i = index; i < redirects.length; i++) {
      final FutureOr<String?> to;
      try {
        to = redirects[i](request);
      } catch (e, s) {
        _redirectFailed(request, e, s);
        return null;
      }
      if (to is Future<String?>) {
        final next = i + 1;
        return to.then(
          (target) => target == null
              ? _runRedirects<T>(request, redirects, next, hops)
              : _redirectTo<T>(request, target, hops),
          onError: (Object e, StackTrace s) {
            _redirectFailed(request, e, s);
            return null;
          },
        );
      }
      if (to != null) return _redirectTo<T>(request, to, hops);
    }
    if (request.isUnknown) return _unknownEntry<T>();
    return NavEntry.create<T>(match: request.match, arguments: request.arguments);
  }

  FutureOr<NavEntry?> _redirectTo<T>(
    NavRequest request,
    String target,
    int hops,
  ) {
    if (target == NavRequest.stop) return null;
    if (target == request.location) {
      // Redirected to itself: go there.
      if (request.isUnknown) return _unknownEntry<T>();
      return NavEntry.create<T>(
        match: request.match,
        arguments: request.arguments,
      );
    }
    if (hops >= 16) {
      _redirectFailed(
        request,
        StateError('More than 16 redirects, last to $target'),
        StackTrace.current,
      );
      return null;
    }
    Fluxy.log('Redirect ${request.location} to $target');
    return _resolve<T>(target, arguments: request.arguments, hops: hops + 1);
  }

  void _redirectFailed(NavRequest request, Object error, StackTrace stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'fluxy_nav',
      context: ErrorDescription('while redirecting ${request.location}'),
    ));
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

  // ---------------------------------------------------------------------
  // Building

  /// The pages the root navigator shows.
  ///
  /// Each entry gives its own page, unless its branch says which pages
  /// take part in the root navigator ([FluxyPage.participatesInRootNavigator]):
  /// then those marked true (a shell page with an outlet, say). A page given
  /// twice (the same shell for several entries) is shown once, where it was
  /// given last.
  List<FluxyPage> _rootPages() {
    if (pickPagesForRootNavigator != null) {
      return pickPagesForRootNavigator!(_stack).toList();
    }
    final entries = _stack.entries;
    // Keys are unique on the stack, so a flat app needs no merging.
    if (!entries.any((e) => e.marksRootNavigator)) {
      return [for (final e in entries) e.page];
    }
    // Insertion-ordered: removing and re-adding a key moves it to the end.
    final pages = <LocalKey, FluxyPage>{};
    for (final entry in entries) {
      if (!entry.marksRootNavigator) {
        pages.remove(entry.key);
        pages[entry.key] = entry.page;
        continue;
      }
      for (final page in entry.branch) {
        if (page.participatesInRootNavigator != true) continue;
        pages.remove(page.key);
        pages[page.key!] = page;
      }
    }
    return pages.values.toList();
  }

  /// The entry an outlet under [parent] shows: the topmost one whose
  /// branch has [parent] (its concrete path or its registered pattern).
  (NavEntry, int)? _outletEntry(String parent) {
    for (final entry in _stack.entries.reversed) {
      final branch = entry.branch;
      final patterns = entry.match.patterns;
      for (var i = 0; i < branch.length; i++) {
        if (branch[i].name == parent ||
            (i < patterns.length && patterns[i] == parent)) {
          return (entry, i);
        }
      }
    }
    return null;
  }

  /// The pages a [FluxyRouterOutlet] under [parent] shows: the branch
  /// pages below [parent], at most [levels] of them.
  List<FluxyPage> outletPages(String parent, {int? levels}) {
    final found = _outletEntry(parent);
    if (found == null) return const [];
    final (entry, index) = found;
    final below = entry.branch.skip(index + 1);
    return (levels == null ? below : below.take(levels)).toList();
  }

  /// An outlet's navigator under [parent] popped [page] itself: the entry
  /// moves up one level (`/home/products/1` becomes `/home/products`).
  void outletDidRemovePage(String parent, Page<Object?> page) {
    _change(() {
      final found = _outletEntry(parent);
      if (found == null) return;
      final (entry, _) = found;
      final branch = entry.branch;
      final index = branch.indexWhere((p) => p.key == page.key);
      if (index < 1) return;
      final location = branch[index - 1].name;
      final isTop = identical(entry, _stack.top);
      final deferred = identical(branch[index], entry.page) ? entry : null;
      if (isTop && _stack.below?.name == location) {
        _commit(_stack.pop(), deferred: deferred);
        return;
      }
      final match = _table.match(location);
      if (match.isUnknown) return;
      var replacement = NavEntry.create<dynamic>(match: match);
      if (_stack.lastAt(replacement.location) != null) {
        replacement = replacement.withKey(UniqueKey());
      }
      _commit(_stack.replace(entry, replacement), deferred: deferred);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _rootPages();
    if (pages.isEmpty) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }
    return FluxyHeroScope(
      child: FluxyNavigator(
        key: navigatorKey,
        onDidRemovePage: _onDidRemovePage,
        pages: pages,
        observers: [_reports, ...?navigatorObservers],
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

  /// The address of the top entry.
  @override
  Uri? get currentConfiguration => _stack.top?.match.uri;

  /// Opens [configuration] (the first address, or one the platform asks
  /// for: a typed URL, browser back / forward), through the redirects.
  @override
  Future<void> setNewRoutePath(Uri configuration) {
    final result = _navigate(
      () => _resolve<dynamic>(configuration.toString()),
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
    _commit(_stack.replaceTopWith(entry), popped: top, popResult: result);
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
        (stack, entry) => stack.replaceTopWith(
          entry,
          mode: entry.page.preventDuplicateHandlingMode,
        ),
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
            : stack.removeUntil((e) => predicate(e.page)).add(entry),
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
        (stack, entry) => stack.replaceTopWith(
          entry,
          mode: entry.page.preventDuplicateHandlingMode,
        ),
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
