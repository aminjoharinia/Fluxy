import 'package:flutter/foundation.dart';

import 'package:fluxy_core/fluxy_core.dart';

import 'lifecycle.dart';

typedef InstanceBuilderCallback<S> = S Function();

/// How an entry makes its instance.
enum DependencyKind {
  /// Registered with an instance (`Fluxy.put`).
  instance,

  /// Built on the first `find` and kept (`Fluxy.lazyPut`). After a
  /// `delete` the builder stays, so the next `find` builds a new one.
  lazy,

  /// A new instance for every `find` (`Fluxy.spawn`).
  factory,
}

/// One registration in a [FluxyScope].
class DependencyEntry<S> {
  DependencyEntry._(
    this.scope,
    this.key,
    this.kind, {
    this.builder,
    S? instance,
    bool created = false,
    this.permanent = false,
    this.tag,
  }) : _instance = instance, // ignore: prefer_initializing_formals
       _created = created; // ignore: prefer_initializing_formals

  /// The scope the entry is registered in.
  final FluxyScope scope;
  final Object key;
  final DependencyKind kind;
  final InstanceBuilderCallback<S>? builder;

  /// Kept by `delete` unless forced.
  final bool permanent;
  final String? tag;

  S? _instance;
  bool _created;

  /// Widgets (`FluxyBuilder(init:)`, `Binder`, `Bind.put`) holding the
  /// instance; see [addOwner].
  int owners = 0;

  /// Whether a widget created or claimed the instance; it is deleted when
  /// the last such widget goes.
  bool widgetOwned = false;

  /// Whether the instance exists (always for [DependencyKind.instance]).
  bool get isCreated => _created;

  /// The instance, if created.
  S? get instance => _instance;

  /// The instance, built (and started) if needed. A [DependencyKind.factory]
  /// entry builds a new one every time.
  S resolve() {
    switch (kind) {
      case DependencyKind.instance:
        return _instance as S;
      case DependencyKind.lazy:
        if (!_created) {
          final built = scope.run(builder!);
          _instance = built;
          _created = true;
          FluxyScope._start(built, tag);
        }
        return _instance as S;
      case DependencyKind.factory:
        final built = scope.run(builder!);
        FluxyScope._start(built, tag);
        if (!identical(scope, FluxyScope.root)) scope._spawned.add(built);
        return built;
    }
  }

  void addOwner() {
    widgetOwned = true;
    owners++;
  }

  /// Returns true when this was the last owner.
  bool removeOwner() {
    if (owners > 0) owners--;
    return owners == 0;
  }

  /// Closes the instance. A lazy entry keeps its builder unless [force];
  /// other entries are removed. False when the entry is [permanent] or a
  /// `FluxyService` and [force] is false.
  bool delete({bool force = false}) {
    if (!force) {
      if (permanent) {
        Fluxy.log('"$key" is permanent; delete it with force: true.');
        return false;
      }
      if (_created && _instance is FluxyServiceMixin) {
        Fluxy.log('"$key" is a FluxyService; delete it with force: true.');
        return false;
      }
    }
    final created = _created;
    final old = _instance;
    if (kind == DependencyKind.lazy && !force) {
      _instance = null;
      _created = false;
    } else {
      scope._entries.remove(key);
    }
    owners = 0;
    widgetOwned = false;
    if (created) FluxyScope._close(old, key);
    return true;
  }

  /// Closes the instance of a lazy entry so the next `find` builds a new
  /// one. Other kinds can't be rebuilt; false.
  bool reload({bool force = false}) {
    if (kind != DependencyKind.lazy) {
      Fluxy.log('"$key" was not registered with lazyPut; it can\'t be reloaded.');
      return false;
    }
    if (permanent && !force) return false;
    if (!_created) return true;
    final old = _instance;
    _instance = null;
    _created = false;
    FluxyScope._close(old, key);
    return true;
  }

  @override
  String toString() => 'DependencyEntry($key, ${kind.name}, ${scope.name})';
}

/// A dependency container. The [root] scope lives as long as the app;
/// child scopes (a page's bindings, a [FluxyScope] widget's dependencies)
/// close with what owns them.
///
/// `Fluxy.put` / `lazyPut` / `spawn` register in [current]: the scope whose
/// [run] is executing (a page's bindings run inside the page's scope), the
/// root otherwise. `Fluxy.find` looks in the open child scopes, newest
/// first, then in the root; [find] on a scope looks in it, then its parents.
class FluxyScope {
  FluxyScope._root() : parent = null, name = 'root';

  /// A child scope of [parent] (default: the root). It's open until
  /// [close].
  FluxyScope({this.name, FluxyScope? parent}) : parent = parent ?? root {
    _open.add(this);
  }

  /// The app's scope.
  static final FluxyScope root = FluxyScope._root();

  static final List<FluxyScope> _open = [];
  static final List<FluxyScope> _registering = [];

  /// Where `Fluxy.put` / `lazyPut` / `spawn` register now.
  static FluxyScope get current =>
      _registering.isEmpty ? root : _registering.last;

  /// The open child scopes, oldest first.
  static List<FluxyScope> get openScopes => List.unmodifiable(_open);

  final FluxyScope? parent;

  /// For logs and errors (a page's name, say).
  final String? name;

  final _entries = <Object, DependencyEntry<dynamic>>{};
  final _spawned = <Object?>[];
  bool _closed = false;

  bool get isClosed => _closed;

  /// The registrations of this scope, oldest first.
  Iterable<DependencyEntry<dynamic>> get entries => _entries.values;

  static Object keyOf(Type type, String? tag) =>
      tag == null ? type : (type, tag);

  /// Runs [body] with this scope as [current].
  T run<T>(T Function() body) {
    _registering.add(this);
    try {
      return body();
    } finally {
      _registering.removeLast();
    }
  }

  // -------------------------------------------------------------------
  // Registering

  /// Registers [instance] and starts it (`onInit`). An instance already
  /// registered under the same type and tag in this scope is closed and
  /// replaced.
  S put<S>(S instance, {String? tag, bool permanent = false}) {
    _checkType<S>('put');
    _checkOpen();
    final key = keyOf(S, tag);
    final old = _entries[key];
    if (old != null) {
      if (old._created && identical(old._instance, instance)) return instance;
      Fluxy.log('"$key" was registered; the new instance replaces it.');
      _entries.remove(key);
      if (old._created) _close(old._instance, key);
    }
    _entries[key] = DependencyEntry<S>._(
      this,
      key,
      DependencyKind.instance,
      instance: instance,
      created: true,
      permanent: permanent,
      tag: tag,
    );
    _start(instance, tag);
    return instance;
  }

  /// Registers [builder], called on the first `find`. Ignored when the type
  /// and tag are already registered in this scope.
  void lazyPut<S>(
    InstanceBuilderCallback<S> builder, {
    String? tag,
    bool permanent = false,
  }) {
    _checkType<S>('lazyPut');
    _checkOpen();
    final key = keyOf(S, tag);
    if (_entries.containsKey(key)) {
      Fluxy.log('"$key" is already registered; lazyPut ignored.');
      return;
    }
    _entries[key] = DependencyEntry<S>._(
      this,
      key,
      DependencyKind.lazy,
      builder: builder,
      permanent: permanent,
      tag: tag,
    );
  }

  /// Registers [builder], called for every `find`. Instances it made in a
  /// child scope are closed with the scope.
  void spawn<S>(
    InstanceBuilderCallback<S> builder, {
    String? tag,
    bool permanent = false,
  }) {
    _checkType<S>('spawn');
    _checkOpen();
    _entries[keyOf(S, tag)] = DependencyEntry<S>._(
      this,
      keyOf(S, tag),
      DependencyKind.factory,
      builder: builder,
      permanent: permanent,
      tag: tag,
    );
  }

  // -------------------------------------------------------------------
  // Finding

  /// The entry registered in this scope only.
  DependencyEntry<dynamic>? local(Object key) => _entries[key];

  /// The entry for [key] in this scope or its parents.
  DependencyEntry<dynamic>? entryOf(Object key) {
    for (FluxyScope? s = this; s != null; s = s.parent) {
      final e = s._entries[key];
      if (e != null) return e;
    }
    return null;
  }

  /// The instance of [S] from this scope or its parents.
  S find<S>({String? tag}) {
    final e = entryOf(keyOf(S, tag));
    if (e == null) throw DependencyNotFound(S, tag, [this]);
    return e.resolve() as S;
  }

  /// The entry `Fluxy.find` uses for [key]: the open child scopes, newest
  /// first, then the root.
  static DependencyEntry<dynamic>? lookup(Object key) {
    if (_open.isEmpty) return root._entries[key];
    for (var i = _open.length - 1; i >= 0; i--) {
      final e = _open[i]._entries[key];
      if (e != null) return e;
    }
    return root._entries[key];
  }

  /// Every entry, in the open child scopes (newest first) and the root.
  static Iterable<DependencyEntry<dynamic>> get allEntries sync* {
    for (var i = _open.length - 1; i >= 0; i--) {
      yield* _open[i]._entries.values.toList();
    }
    yield* root._entries.values.toList();
  }

  // -------------------------------------------------------------------
  // Closing

  /// Closes every instance of this scope (newest first, `permanent` and
  /// services too) and the ones its factories made, then removes it.
  /// Closing the root clears it; it stays usable.
  void close() {
    if (_closed) return;
    final entries = _entries.values.toList().reversed;
    for (final e in entries) {
      e.delete(force: true);
    }
    _entries.clear();
    for (final i in _spawned.reversed) {
      _close(i, 'spawned');
    }
    _spawned.clear();
    if (identical(this, root)) return;
    _closed = true;
    _open.remove(this);
  }

  /// Closes the open child scopes (newest first), then empties the root.
  static void resetAll() {
    for (final s in _open.reversed.toList()) {
      s.close();
    }
    _open.clear();
    _registering.clear();
    root.close();
  }

  // -------------------------------------------------------------------

  static void _start(Object? instance, String? tag) {
    if (instance is FluxyLifeCycleMixin && !instance.initialized) {
      instance.onStart();
      Fluxy.log(
        tag == null
            ? 'Instance "${instance.runtimeType}" has been initialized'
            : 'Instance "${instance.runtimeType}" with tag "$tag" has been initialized',
      );
    }
  }

  static void _close(Object? instance, Object key) {
    if (instance is FluxyLifeCycleMixin) {
      instance.onDelete();
      Fluxy.log('"$key" onDelete() called');
    }
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('The scope ${name ?? ''} is closed.');
    }
  }

  static Type _typeOf<T>() => T;

  static void _checkType<S>(String method) {
    if (S == dynamic ||
        S == _typeOf<void>() ||
        S == Null ||
        S == _typeOf<Object?>()) {
      throw ArgumentError(
        'Fluxy.$method needs a type, got <$S>. Write the type '
        '(Fluxy.$method<MyController>(...)); `void f() => Fluxy.$method(...)` '
        'infers void.',
      );
    }
  }

  @override
  String toString() => 'FluxyScope(${name ?? 'unnamed'}, ${_entries.length})';
}

/// `Fluxy.find` (or a scope's `find`) found nothing registered for the type
/// and tag.
class DependencyNotFound extends FlutterError {
  DependencyNotFound(Type type, String? tag, [List<FluxyScope>? searched])
    : super.fromParts([
        ErrorSummary(
          '"$type"${tag == null ? '' : ' with tag "$tag"'} is not registered.',
        ),
        ErrorHint(
          'Register it with Fluxy.put($type(...)) or '
          'Fluxy.lazyPut(() => $type(...)), or in the bindings of the page '
          'that uses it.',
        ),
        if (searched != null)
          ErrorDescription(
            'Searched: ${[for (final s in searched) for (FluxyScope? p = s; p != null; p = p.parent) p.name ?? 'unnamed'].join(' > ')}.',
          ),
      ]);
}
