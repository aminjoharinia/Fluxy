import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';

import 'scope.dart';

typedef InstanceCreateBuilderCallback<S> = S Function(BuildContext _);

typedef AsyncInstanceBuilderCallback<S> = Future<S> Function();

class InstanceInfo {
  final bool? isPermanent;
  final bool? isSingleton;
  bool get isCreate => !isSingleton!;
  final bool isRegistered;
  final bool isPrepared;
  final bool? isInit;
  const InstanceInfo({
    required this.isPermanent,
    required this.isSingleton,
    required this.isRegistered,
    required this.isPrepared,
    required this.isInit,
  });

  @override
  String toString() {
    return 'InstanceInfo(isPermanent: $isPermanent, isSingleton: $isSingleton, isRegistered: $isRegistered, isPrepared: $isPrepared, isInit: $isInit)';
  }
}

extension ResetInstance on FluxyInterface {
  /// Closes every instance (child scopes first, newest first; permanent
  /// ones and services too) and empties the registry. For the end of a
  /// test.
  bool resetInstance() {
    FluxyScope.resetAll();
    return true;
  }
}

/// Dependency injection through `Fluxy`.
///
/// `put` / `lazyPut` / `spawn` register in [FluxyScope.current]: the scope of
/// the page whose bindings are running, or the app's root scope, where they
/// stay until deleted. `find` looks in the open page and widget scopes,
/// newest first, then the root.
extension Inst on FluxyInterface {
  T call<T>() => find<T>();

  /// Registers [dependency] and starts it (`onInit`). One already
  /// registered under the same type and tag (in the same scope) is closed
  /// and replaced.
  S put<S>(S dependency, {String? tag, bool permanent = false}) =>
      FluxyScope.current.put<S>(dependency, tag: tag, permanent: permanent);

  /// Registers [builder]; the first `find` builds the instance and keeps
  /// it. After `delete` the builder stays: the next `find` builds a new one
  /// (`delete(force: true)` removes the registration). A second `lazyPut`
  /// of the same type and tag is ignored.
  void lazyPut<S>(
    InstanceBuilderCallback<S> builder, {
    String? tag,
    bool permanent = false,
  }) => FluxyScope.current.lazyPut<S>(builder, tag: tag, permanent: permanent);

  /// Registers [builder]; every `find` builds a new instance. Instances made
  /// for a page scope are closed with the page.
  void spawn<S>(
    InstanceBuilderCallback<S> builder, {
    String? tag,
    bool permanent = false,
  }) => FluxyScope.current.spawn<S>(builder, tag: tag, permanent: permanent);

  /// The registered [S] (built and started if needed).
  S find<S>({String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(S, tag));
    if (entry == null) throw DependencyNotFound(S, tag);
    return entry.resolve() as S;
  }

  /// The registered [S], or null.
  S? findOrNull<S>({String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(S, tag));
    return entry?.resolve() as S?;
  }

  S putOrFind<S>(InstanceBuilderCallback<S> dep, {String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(S, tag));
    if (entry != null) return entry.resolve() as S;
    return put<S>(dep(), tag: tag);
  }

  InstanceInfo getInstanceInfo<S>({String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(S, tag));
    return InstanceInfo(
      isPermanent: entry?.permanent,
      isSingleton: entry == null ? null : entry.kind != DependencyKind.factory,
      isRegistered: entry != null,
      isPrepared: entry != null &&
          entry.kind == DependencyKind.lazy &&
          !entry.isCreated,
      isInit: entry?.isCreated,
    );
  }

  /// Replaces the registered [P] with [child], closing the old instance
  /// (permanent ones and services too) and keeping its scope and
  /// `permanent` flag.
  void replace<P>(P child, {String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(P, tag));
    if (entry == null) {
      put<P>(child, tag: tag);
      return;
    }
    entry.delete(force: true);
    entry.scope.put<P>(child, tag: tag, permanent: entry.permanent);
  }

  /// Like [replace], with a builder called on the next `find`.
  void lazyReplace<P>(InstanceBuilderCallback<P> builder, {String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(P, tag));
    if (entry == null) {
      lazyPut<P>(builder, tag: tag);
      return;
    }
    entry.delete(force: true);
    entry.scope.lazyPut<P>(builder, tag: tag, permanent: entry.permanent);
  }

  /// Closes the registered [S] (`onDelete`). A `put` or `spawn`
  /// registration is removed; a `lazyPut` one keeps its builder unless
  /// [force]. Permanent instances and services need [force].
  bool delete<S>({String? tag, bool force = false}) {
    final key = FluxyScope.keyOf(S, tag);
    final entry = FluxyScope.lookup(key);
    if (entry == null) {
      Fluxy.log('Instance "$key" already removed.');
      return false;
    }
    return entry.delete(force: force);
  }

  /// [delete] for every registration.
  void deleteAll({bool force = false}) {
    for (final entry in FluxyScope.allEntries) {
      entry.delete(force: force);
    }
  }

  /// Closes a `lazyPut` instance so the next `find` builds a new one.
  void reload<S>({String? tag, bool force = false}) {
    FluxyScope.lookup(FluxyScope.keyOf(S, tag))?.reload(force: force);
  }

  /// [reload] for every `lazyPut` registration.
  void reloadAll({bool force = false}) {
    for (final entry in FluxyScope.allEntries) {
      if (entry.kind == DependencyKind.lazy) entry.reload(force: force);
    }
  }

  /// Makes every `find<S>(tag:)` return [instance], whatever is
  /// registered, until [clearOverrides] or `Fluxy.reset()`. For tests.
  S overrideWith<S>(S instance, {String? tag}) =>
      FluxyScope.overrideAt<S>(FluxyScope.keyOf(S, tag), instance);

  /// Drops the overrides set with [overrideWith] (or `Dep.overrideWith`).
  void clearOverrides() => FluxyScope.clearOverrides();

  bool isRegistered<S>({String? tag}) =>
      FluxyScope.lookup(FluxyScope.keyOf(S, tag)) != null;

  /// Whether [S] is registered with `lazyPut` and not built yet.
  bool isPrepared<S>({String? tag}) {
    final entry = FluxyScope.lookup(FluxyScope.keyOf(S, tag));
    return entry != null &&
        entry.kind == DependencyKind.lazy &&
        !entry.isCreated;
  }
}
