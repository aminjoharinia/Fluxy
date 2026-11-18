import 'package:flutter/widgets.dart';

import 'scope.dart';

/// Gives [child] its own [FluxyScope]: [dependencies] run inside it (their
/// `Fluxy.put` / `lazyPut` register there), and everything in it is closed
/// when this widget goes.
///
/// `context.find<T>()` below it looks in this scope, then the enclosing
/// ones, then the root.
class DependencyScope extends StatefulWidget {
  const DependencyScope({
    super.key,
    this.name,
    this.dependencies,
    required this.child,
  });

  /// For logs and errors.
  final String? name;

  /// Registers the scope's dependencies (runs once, inside the scope).
  final void Function()? dependencies;

  final Widget child;

  /// The scope of the nearest [DependencyScope] (or a page with bindings)
  /// above [context], or null.
  static FluxyScope? maybeOf(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<
      ScopeProvider
    >();
    return (element?.widget as ScopeProvider?)?.scope;
  }

  /// [maybeOf], or the root scope.
  static FluxyScope of(BuildContext context) =>
      maybeOf(context) ?? FluxyScope.root;

  @override
  State<DependencyScope> createState() => _DependencyScopeState();
}

class _DependencyScopeState extends State<DependencyScope> {
  late final FluxyScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = FluxyScope(
      name: widget.name,
      parent: DependencyScope.maybeOf(context),
    );
    final dependencies = widget.dependencies;
    if (dependencies != null) _scope.run(dependencies);
  }

  @override
  void dispose() {
    _scope.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScopeProvider(scope: _scope, child: widget.child);
}

/// Makes [scope] the scope of [child] for [DependencyScope.of] and
/// `context.find`. It doesn't close the scope; whoever made it does (a
/// page route closes its page scope when it's disposed).
class ScopeProvider extends InheritedWidget {
  const ScopeProvider({super.key, required this.scope, required super.child});

  final FluxyScope scope;

  @override
  bool updateShouldNotify(ScopeProvider oldWidget) =>
      !identical(scope, oldWidget.scope);
}

extension FluxyScopeContext on BuildContext {
  /// The registered [S], looked up from this context's scope outwards to
  /// the root (see [DependencyScope]).
  S find<S>({String? tag}) => DependencyScope.of(this).find<S>(tag: tag);
}
