import 'package:flutter/foundation.dart';

/// Collects the cleanups of reactive objects (effects, `Computed`s, workers)
/// created while it is [current], and runs them on [dispose].
///
/// A controller has one: everything created inside its `onInit` / `onReady`
/// is disposed after its `onClose`. Objects created elsewhere (for example a
/// field initializer) can be handed to it with `own(...)`.
///
/// ```dart
/// final owner = ReactiveOwner();
/// owner.run(() {
///   effect(() => debugPrint('${count.value}'));
/// });
/// owner.dispose(); // the effect stops
/// ```
class ReactiveOwner {
  static ReactiveOwner? _current;

  /// The owner that objects created right now register with, if any.
  static ReactiveOwner? get current => _current;

  /// Registers [disposer] with the [current] owner. No-op without one.
  static void register(VoidCallback disposer) => _current?.onDispose(disposer);

  /// Runs [fn] with no current owner: what it creates is not collected.
  static T untracked<T>(T Function() fn) {
    final previous = _current;
    _current = null;
    try {
      return fn();
    } finally {
      _current = previous;
    }
  }

  List<VoidCallback>? _disposers = <VoidCallback>[];

  bool get isDisposed => _disposers == null;

  /// How many cleanups are registered.
  int get length => _disposers?.length ?? 0;

  /// Adds a cleanup. After [dispose], it runs at once (the owner is gone, so
  /// whatever it cleans up must not outlive it).
  void onDispose(VoidCallback disposer) {
    final list = _disposers;
    if (list == null) {
      disposer();
    } else {
      list.add(disposer);
    }
  }

  /// Runs [fn] with this as the [current] owner.
  T run<T>(T Function() fn) {
    final previous = _current;
    _current = this;
    try {
      return fn();
    } finally {
      _current = previous;
    }
  }

  /// Runs every cleanup, newest first. A cleanup that throws is reported and
  /// the others still run.
  void dispose() {
    final list = _disposers;
    if (list == null) return;
    _disposers = null;
    for (var i = list.length - 1; i >= 0; i--) {
      try {
        list[i]();
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'fluxy_state',
          context: ErrorDescription('while disposing a reactive owner'),
        ));
      }
    }
  }
}
