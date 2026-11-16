import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../get_rx/src/rx_types/rx_types.dart';
import '../simple/list_notifier.dart';
import '../simple/reactive_owner.dart';
import 'rx_notifier.dart';

/// A value derived from other Rx values, cached until one of them changes.
///
/// ```dart
/// final items = 1.obs;
/// final price = 25.obs;
/// final total = Computed(() => items.value * price.value);
///
/// Obx(() => Text('${total.value}'));
/// ```
///
/// - It tracks the Rx values (and other `Computed`s) [compute] reads, the
///   same way `Obx` does: after each run, values it stopped reading are
///   dropped.
/// - **Glitch-free.** A read always gives the value for the current state of
///   every source. When a source changes, a `Computed` only learns that it
///   *may* be out of date; it recomputes when it is read (or, while
///   something listens, right away), after first bringing any `Computed`
///   source up to date. So with `b` and `c` both derived from `a` and
///   `d = b + c`, a change of `a` never shows `d` a new `b` with an old `c`,
///   and `d` recomputes once.
/// - It recomputes only when a source really changed (each source carries a
///   version), and notifies its listeners only when the result is different
///   (`==`, or [equals]).
/// - With no listeners it holds no subscriptions (nothing keeps it alive) and
///   checks its sources' versions on the next read: no recompute if none
///   changed.
/// - Inside `Get.batch` it already gives fresh values when read; listeners
///   are notified once, after the batch.
/// - If [compute] throws, the error is kept and thrown at each read until a
///   source changes.
///
/// Created inside a controller's `onInit` / `onReady`, it is disposed with the
/// controller; elsewhere, wrap it in the controller's `own(...)` or call
/// [dispose] when it is no longer needed.
class Computed<T> extends ListNotifierSingle implements ValueListenable<T> {
  Computed(this._compute, {this.equals}) {
    // Created inside a controller's onInit / onReady: disposed with it.
    ReactiveOwner.register(() {
      if (!isDisposed) dispose();
    });
  }

  final T Function() _compute;

  /// Decides whether a new result counts as unchanged (no notification).
  /// Defaults to `==`.
  final bool Function(T previous, T next)? equals;
  final _sources = TrackedSources();

  late T _value;
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasRun = false;
  bool _computing = false;

  /// Goes up when the result (or error) changes.
  int _valueVersion = 0;

  /// [_valueVersion] the listeners were last told about.
  int _notifiedVersion = 0;

  /// [Notifier.globalVersion] when the sources were last checked.
  int _checkedAt = -1;

  /// The current value. Inside an `Obx`, subscribes it to this value.
  @override
  T get value {
    reportRead();
    return peek;
  }

  /// The current value, without subscribing the building observer.
  T get peek {
    _validate();
    final error = _error;
    if (error != null) Error.throwWithStackTrace(error, _stackTrace!);
    return _value;
  }

  /// Up to date before it is returned, so whoever compares it (another
  /// `Computed`, an `Effect`) never sees a stale version.
  @override
  int get reactiveVersion {
    if (!isDisposed) _validate();
    return _valueVersion;
  }

  @override
  @protected
  bool get bumpsGlobalVersion => false;

  void _validate() {
    if (_computing) {
      throw StateError('A Computed read its own value while computing it.');
    }
    final now = Notifier.instance.globalVersion;
    if (_hasRun && _checkedAt == now) return;
    if (!_hasRun || _sources.changed) _recompute();
    _checkedAt = now;
  }

  void _recompute() {
    late T next;
    Object? error;
    StackTrace? stackTrace;
    _computing = true;
    try {
      next = _sources.track(_compute);
    } catch (e, st) {
      error = e;
      stackTrace = st;
    } finally {
      _computing = false;
    }
    final first = !_hasRun;
    _hasRun = true;
    if (error != null) {
      _error = error;
      _stackTrace = stackTrace;
      _valueVersion++;
      return;
    }
    final wasError = _error != null;
    _error = null;
    _stackTrace = null;
    if (first ||
        wasError ||
        !(equals?.call(_value, next) ?? _value == next)) {
      _value = next;
      _valueVersion++;
    }
  }

  void _sourceChanged() {
    if (isDisposed) return;
    try {
      _validate();
    } catch (_) {
      // Only a cycle gets here (compute errors are kept as the value). Do
      // not throw into the source's notify loop; the listener's read throws.
      _valueVersion++;
    }
    if (_valueVersion != _notifiedVersion) {
      _notifiedVersion = _valueVersion;
      refresh();
    }
  }

  void _wake() {
    try {
      _validate();
    } catch (_) {}
    _notifiedVersion = _valueVersion;
    _sources.listen(_sourceChanged);
  }

  void _maybeSleep() {
    if (!isDisposed && listenersLength == 0) _sources.unlisten();
  }

  @override
  Disposer addListener(GetStateUpdate listener) {
    final wake = listenersLength == 0;
    final remove = super.addListener(listener);
    if (wake) _wake();
    return () {
      remove();
      _maybeSleep();
    };
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _maybeSleep();
  }

  @override
  void dispose() {
    _sources.dispose();
    super.dispose();
  }

  @override
  String toString() => '$value';
}

/// What [effect] runs. It may return a `void Function()`: that cleanup runs
/// before the next run and on [Effect.dispose].
typedef EffectCallback = dynamic Function();

/// Runs [fn] now and again whenever an Rx or `Computed` it read changes.
///
/// ```dart
/// final stop = effect(() {
///   debugPrint('cart: ${items.length} items, total ${total.value}');
/// });
///
/// effect(() {
///   final sub = socket.listen(roomId.value);
///   return sub.cancel; // runs before the next run and on dispose
/// });
///
/// stop.dispose();
/// ```
///
/// - It follows what its last run read, like `Obx`.
/// - It runs synchronously, but after the change that triggered it is fully
///   applied: once per notify or `Get.batch`, however many of its sources
///   changed, and always with up-to-date `Computed` values.
/// - Changes it makes are held until it returns (it runs inside a batch).
///   An effect that writes a value it reads loops; that is stopped with a
///   `StateError` after [Notifier.maxReactionRounds] rounds.
/// - An error on the first run is thrown here (and the effect is disposed);
///   later errors are reported with `FlutterError.reportError`.
///
/// Created inside a controller's `onInit` / `onReady`, it is disposed with the
/// controller (see [ReactiveOwner]); elsewhere, wrap it in `own(...)` or
/// call [Effect.dispose].
Effect effect(EffectCallback fn) => Effect(fn);

/// See [effect].
class Effect implements ScheduledReaction {
  Effect(this._fn) {
    _sources.listen(_notified);
    try {
      _run();
    } catch (_) {
      dispose();
      rethrow;
    }
    // Created inside a controller's onInit / onReady: disposed with it.
    ReactiveOwner.register(dispose);
  }

  final EffectCallback _fn;
  final _sources = TrackedSources();
  VoidCallback? _cleanup;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _notified() {
    if (!_disposed) Notifier.instance.schedule(this);
  }

  @override
  void runScheduled() {
    // Skipped when nothing it read really changed since its last run (for
    // example two batched changes, the second of which it already saw).
    if (_disposed || !_sources.changed) return;
    try {
      _run();
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'fluxy_state',
        context: ErrorDescription('while running an effect'),
      ));
    }
  }

  void _run() {
    Notifier.instance.batch(() {
      _runCleanup();
      if (_disposed) return;
      final result = _sources.track(_fn);
      if (result is VoidCallback) _cleanup = result;
    });
  }

  void _runCleanup() {
    final cleanup = _cleanup;
    _cleanup = null;
    if (cleanup != null) Notifier.instance.untrack(cleanup);
  }

  /// Stops it and runs its cleanup.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sources.dispose();
    _runCleanup();
  }
}

/// The state of an async load as an Rx: [GetStatus.loading], then
/// [GetStatus.success] with the data or [GetStatus.error].
///
/// ```dart
/// final rooms = RxFuture(() => api.fetchRooms());
///
/// Obx(() => rooms.when(
///   loading: () => const CircularProgressIndicator(),
///   success: (list) => RoomList(list),
///   error: (e) => Text('$e'),
/// ));
///
/// rooms.reload(); // keeps showing the old list (lastData) while loading
/// ```
///
/// Only the newest load counts: if [reload] is called again before an older
/// load finished, the older result is ignored, so a slow response can never
/// overwrite a newer one.
class RxFuture<T> extends Rx<GetStatus<T>> {
  /// Starts loading at once unless [lazy] is true (then call [reload]).
  RxFuture(this._load, {bool lazy = false}) : super(GetStatus<T>.loading()) {
    if (!lazy) reload();
  }

  final Future<T> Function() _load;
  int _generation = 0;
  T? _lastData;
  StackTrace? _lastStackTrace;

  /// The data of the last successful load, also while a newer load runs or
  /// after it failed. Good for showing old content during a refresh.
  T? get lastData {
    reportRead();
    return _lastData;
  }

  /// The stack trace of the last failed load.
  StackTrace? get lastStackTrace => _lastStackTrace;

  /// Loads again. Completes when this load (or a newer one) is done; never
  /// throws, the error is in [value]. While it runs, [value] is a loading
  /// status that keeps the last data (`value.isRefreshing`), and a failure
  /// keeps it too (`value.data`).
  Future<void> reload() async {
    final generation = ++_generation;
    value = peek.toLoading();
    try {
      final data = await _load();
      if (generation != _generation || isDisposed) return;
      _lastData = data;
      value = GetStatus<T>.success(data);
    } catch (e, st) {
      if (generation != _generation || isDisposed) return;
      _lastStackTrace = st;
      value = peek.toError(e, st);
    }
  }

  /// Builds from the current status. Inside an `Obx`, subscribes it.
  R when<R>({
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error) error,
  }) {
    return switch (value) {
      SuccessStatus(:final data) => success(data),
      ErrorStatus(error: final e) => error(e),
      LoadingStatus() || EmptyStatus() => loading(),
    };
  }
}
