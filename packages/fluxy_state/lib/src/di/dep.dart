import 'package:flutter/widgets.dart';

import 'scope.dart';
import 'widgets.dart';

/// A typed handle to a dependency: the handle is its own key, so there are
/// no string tags and no two registrations of one type can collide.
///
/// ```dart
/// final places = Dep(() => PlacesController());
///
/// places().select(id);        // built on first use, kept for the app
/// places.of(context);         // from the context's scope outwards
/// ```
///
/// The first [call] registers the builder in the root scope (lazily, for
/// the app's lifetime) unless the handle is registered already. [register]
/// inside a page's bindings (or a [DependencyScope]) gives that page its own
/// instance, closed with it; lookups from there find it first.
class Dep<T> {
  Dep(this.builder, {this.name, this.permanent = false});

  /// Builds the instance.
  final T Function() builder;

  /// For logs and errors.
  final String? name;

  /// Kept by `delete` unless forced.
  final bool permanent;

  /// The instance, registering the handle in the root scope first if it
  /// isn't registered anywhere.
  T call() {
    final entry =
        FluxyScope.lookup(this) ??
        (FluxyScope.root
              ..lazyPutAt<T>(this, builder, permanent: permanent))
            .local(this)!;
    return entry.resolve() as T;
  }

  /// The instance, looked up from [context]'s scope outwards (see
  /// [DependencyScope]); registered in the root scope if found nowhere.
  T of(BuildContext context) {
    final entry = DependencyScope.of(context).entryOf(this);
    if (entry != null) return entry.resolve() as T;
    return call();
  }

  /// Registers the builder in [FluxyScope.current] (a page's scope while its
  /// bindings run). Ignored if it's already registered there.
  void register() => FluxyScope.current.lazyPutAt<T>(
    this,
    builder,
    permanent: permanent,
  );

  /// Registers [instance] in [FluxyScope.current], replacing (and closing)
  /// one registered there.
  T put(T instance) =>
      FluxyScope.current.putAt<T>(this, instance, permanent: permanent);

  /// Whether the handle is registered in any open scope.
  bool get isRegistered => FluxyScope.lookup(this) != null;

  /// Closes the instance; the builder stays registered (the next call
  /// builds a new one) unless [force].
  bool delete({bool force = false}) =>
      FluxyScope.lookup(this)?.delete(force: force) ?? false;

  /// Makes this handle return [instance] until `Fluxy.reset()` (or
  /// [FluxyScope.clearOverrides]). For tests.
  T overrideWith(T instance) => FluxyScope.overrideAt<T>(this, instance);

  @override
  String toString() => 'Dep<$T>(${name ?? identityHashCode(this)})';
}
