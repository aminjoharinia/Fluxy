import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

class FluxyPageRoute<T> extends PageRoute<T>
    with FluxyPageRouteTransitionMixin<T> {
  /// Creates a page route for use in an iOS designed app.
  ///
  /// The [builder], [maintainState], and [fullscreenDialog] arguments must not
  /// be null.
  FluxyPageRoute({
    super.settings,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.opaque = true,
    this.parameter,
    this.gestureWidth,
    this.curve,
    this.alignment,
    this.transition,
    this.popGesture,
    this.customTransition,
    this.barrierDismissible = false,
    this.barrierColor,
    BindingsInterface? binding,
    List<BindingsInterface> bindings = const [],
    this.binds,
    this.routeName,
    this.page,
    this.title,
    this.showCupertinoParallax = true,
    this.barrierLabel,
    this.maintainState = true,
    super.fullscreenDialog,
  }) : bindings = (binding == null) ? bindings : [...bindings, binding];

  @override
  final Duration transitionDuration;
  @override
  final Duration reverseTransitionDuration;

  final FluxyPageBuilder? page;
  final String? routeName;
  //final String reference;
  final CustomTransition? customTransition;
  final List<BindingsInterface> bindings;
  final Map<String, String>? parameter;
  final List<Bind>? binds;

  @override
  final bool showCupertinoParallax;

  @override
  final bool opaque;
  final bool? popGesture;

  @override
  final bool barrierDismissible;
  final Transition? transition;
  final Curve? curve;
  final Alignment? alignment;

  @override
  final Color? barrierColor;

  @override
  final String? barrierLabel;

  @override
  final bool maintainState;

  @override
  void dispose() {
    super.dispose();
    _child = null;
    _scope?.close();
    _scope = null;
  }

  Widget? _child;

  /// The page's scope, when it has bindings: they register in it, and it
  /// closes (with everything in it) when the route is disposed.
  FluxyScope? _scope;

  /// The page's own scope, if it has one.
  FluxyScope? get scope => _scope;

  Widget _getChild(BuildContext context) {
    if (_child != null) return _child!;
    final pageToBuild = page!;
    final hasDependencies =
        bindings.isNotEmpty || (binds != null && binds!.isNotEmpty);
    if (!hasDependencies) return _child = pageToBuild();

    final scope = _scope = FluxyScope(
      name: routeName ?? settings.name,
      parent: DependencyScope.maybeOf(context),
    );
    final built = scope.run(() {
      final all = <Bind>[...?binds];
      for (final binding in bindings) {
        final dependencies = binding.dependencies();
        if (dependencies is List<Bind>) all.addAll(dependencies);
      }
      final child = pageToBuild();
      return all.isEmpty ? child : Binds(binds: all, child: child);
    });
    return _child = ScopeProvider(scope: scope, child: built);
  }

  @override
  Widget buildContent(BuildContext context) {
    return _getChild(context);
  }

  @override
  final String? title;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  final double Function(BuildContext context)? gestureWidth;
}
