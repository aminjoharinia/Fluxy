import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

/// Shows the pages of the current address that sit below [parent], in a
/// nested navigator.
///
/// Put it in the page registered as [parent] (a shell with tabs or a side
/// bar, say). For `/home/products/7`, an outlet with `parent: '/home'`
/// shows `/home/products` with `/home/products/7` above it. [parent] is
/// the parent's full path, concrete (`/user/7`) or as registered
/// (`/user/:id`).
///
/// [levels] limits how many levels it shows: an outlet whose child pages
/// have outlets of their own shows one level (`levels: 1`).
///
/// When no page sits below [parent] (the address is [parent] itself), it
/// shows the page registered as [initialRoute], or else [emptyWidget].
///
/// A page popped inside the outlet (back gesture, `Navigator.pop`) moves
/// the address up one level, and the URL follows.
class FluxyRouterOutlet extends StatefulWidget {
  const FluxyRouterOutlet({
    super.key,
    required this.parent,
    this.initialRoute,
    this.levels,
    this.filterPages,
    this.emptyWidget,
    this.navigatorKey,
    this.restorationScopeId,
    this.delegate,
  });

  final String parent;
  final String? initialRoute;
  final int? levels;

  /// Changes the picked pages before they're shown.
  final Iterable<FluxyPage> Function(Iterable<FluxyPage> pages)? filterPages;
  final Widget? emptyWidget;

  /// The nested navigator's key; one is made when null.
  final GlobalKey<NavigatorState>? navigatorKey;
  final String? restorationScopeId;

  /// Defaults to the enclosing router's delegate.
  final FluxyDelegate? delegate;

  @override
  State<FluxyRouterOutlet> createState() => _FluxyRouterOutletState();
}

class _FluxyRouterOutletState extends State<FluxyRouterOutlet> {
  FluxyDelegate? _delegate;
  GlobalKey<NavigatorState>? _ownKey;

  GlobalKey<NavigatorState> get _key =>
      widget.navigatorKey ?? (_ownKey ??= GlobalKey<NavigatorState>());

  void _changed() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(FluxyRouterOutlet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey != widget.navigatorKey) {
      _delegate?.detachOutlet(oldWidget.navigatorKey ?? _ownKey!);
    }
    _listen();
  }

  void _listen() {
    final delegate = widget.delegate ??
        (Router.maybeOf(context)?.routerDelegate as FluxyDelegate?) ??
        Fluxy.rootController.rootDelegate;
    if (identical(delegate, _delegate)) {
      delegate.attachOutlet(_key);
      return;
    }
    _delegate
      ?..removeListener(_changed)
      ..detachOutlet(_key);
    _delegate = delegate
      ..addListener(_changed)
      ..attachOutlet(_key);
  }

  @override
  void dispose() {
    _delegate
      ?..removeListener(_changed)
      ..detachOutlet(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delegate = _delegate!;
    Iterable<FluxyPage> pages =
        delegate.outletPages(widget.parent, levels: widget.levels);
    if (pages.isEmpty && widget.initialRoute != null) {
      final initial = delegate.routeTable.match(widget.initialRoute!).page;
      if (initial != null) pages = [initial];
    }
    if (widget.filterPages != null) pages = widget.filterPages!(pages);
    final list = pages.toList();
    if (list.isEmpty) return widget.emptyWidget ?? const SizedBox.shrink();
    return InheritedNavigator(
      navigatorKey: _key,
      child: FluxyHeroScope(
        nested: true,
        child: FluxyNavigator(
          key: _key,
          restorationScopeId: widget.restorationScopeId,
          pages: list,
          onDidRemovePage: (page) =>
              delegate.outletDidRemovePage(widget.parent, page),
        ),
      ),
    );
  }
}

class InheritedNavigator extends InheritedWidget {
  const InheritedNavigator({
    super.key,
    required super.child,
    required this.navigatorKey,
  });
  final GlobalKey<NavigatorState> navigatorKey;

  static InheritedNavigator? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedNavigator>();
  }

  @override
  bool updateShouldNotify(InheritedNavigator oldWidget) {
    return true;
  }
}

extension NavKeyExt on BuildContext {
  GlobalKey<NavigatorState>? get parentNavigatorKey {
    return InheritedNavigator.of(this)?.navigatorKey;
  }
}

typedef NavigatorItemBuilderBuilder = Widget Function(
    BuildContext context, List<String> routes, int index);

class IndexedRouteBuilder<T> extends StatelessWidget {
  const IndexedRouteBuilder({
    super.key,
    required this.builder,
    required this.routes,
  });
  final List<String> routes;
  final NavigatorItemBuilderBuilder builder;

// Method to get the current index based on the route
  int _getCurrentIndex(String currentLocation) {
    for (int i = 0; i < routes.length; i++) {
      if (currentLocation.startsWith(routes[i])) {
        return i;
      }
    }
    return 0; // default index
  }

  @override
  Widget build(BuildContext context) {
    final location = context.location;
    final index = _getCurrentIndex(location);

    return builder(context, routes, index);
  }
}

mixin RouterListenerMixin<T extends StatefulWidget> on State<T> {
  RouterDelegate? delegate;

  void _listener() {
    setState(() {});
  }

  VoidCallback? disposer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    disposer?.call();
    final router = Router.of(context);
    delegate ??= router.routerDelegate as FluxyDelegate;

    delegate?.addListener(_listener);
    disposer = () => delegate?.removeListener(_listener);
  }

  @override
  void dispose() {
    super.dispose();
    disposer?.call();
  }
}

class RouterListenerInherited extends InheritedWidget {
  const RouterListenerInherited({
    super.key,
    required super.child,
  });

  static RouterListenerInherited? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RouterListenerInherited>();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

class RouterListener extends StatefulWidget {
  const RouterListener({
    super.key,
    required this.builder,
  });
  final WidgetBuilder builder;

  @override
  State<RouterListener> createState() => RouteListenerState();
}

class RouteListenerState extends State<RouterListener>
    with RouterListenerMixin {
  @override
  Widget build(BuildContext context) {
    return RouterListenerInherited(child: Builder(builder: widget.builder));
  }
}

class BackButtonCallback extends StatefulWidget {
  const BackButtonCallback({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<BackButtonCallback> createState() => RouterListenerState();
}

class RouterListenerState extends State<BackButtonCallback>
    with RouterListenerMixin {
  late ChildBackButtonDispatcher backButtonDispatcher;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = Router.of(context);
    backButtonDispatcher =
        router.backButtonDispatcher!.createChildBackButtonDispatcher();
  }

  @override
  Widget build(BuildContext context) {
    backButtonDispatcher.takePriority();
    return widget.builder(context);
  }
}
