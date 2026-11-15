import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../get_rx/src/rx_types/rx_types.dart';
import '../simple/list_notifier.dart';
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
/// - It tracks the Rx values [compute] reads, the same way `Obx` does: after
///   each run, values it stopped reading are unsubscribed.
/// - While something listens to it (an `Obx`, `addListener`), it recomputes
///   as soon as a source changes and notifies only when the result is
///   different (`==`, or [equals]). With no listeners it just marks itself
///   stale and recomputes on the next read.
/// - Inside `Get.batch`, sources notify after the batch, so it recomputes once
///   per changed source at that point.
///
/// Call [dispose] when it is no longer needed (for example in a controller's
/// `onClose`).
class Computed<T> extends ListNotifierSingle implements ValueListenable<T> {
  Computed(this._compute, {this.equals});

  final T Function() _compute;

  /// Decides whether a new result counts as unchanged (no notification).
  /// Defaults to `==`.
  final bool Function(T previous, T next)? equals;
  final _sources = ObserverSubscriptions();

  late T _value;
  bool _stale = true;
  bool _computing = false;

  /// The current value. Inside an `Obx`, subscribes it to this value.
  @override
  T get value {
    reportRead();
    return peek;
  }

  /// The current value, without subscribing the building observer.
  T get peek {
    if (_stale) _run();
    return _value;
  }

  void _run() {
    if (_computing) {
      throw StateError('A Computed read its own value while computing it.');
    }
    _computing = true;
    try {
      _value = Notifier.instance.append(
        NotifyData(
          updater: _sourceChanged,
          disposers: <Disposer>[],
          subscriptions: _sources,
          throwException: false,
        ),
        _compute,
      );
      _stale = false;
    } finally {
      _computing = false;
    }
  }

  void _sourceChanged() {
    if (isDisposed) return;
    if (listenersLength == 0) {
      _stale = true;
      return;
    }
    final previous = _value;
    _run();
    final same = equals?.call(previous, _value) ?? previous == _value;
    if (!same) refresh();
  }

  @override
  void dispose() {
    _sources.dispose();
    super.dispose();
  }

  @override
  String toString() => '$value';
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
  /// throws, the error is in [value].
  Future<void> reload() async {
    final generation = ++_generation;
    value = GetStatus<T>.loading();
    try {
      final data = await _load();
      if (generation != _generation || isDisposed) return;
      _lastData = data;
      value = GetStatus<T>.success(data);
    } catch (e, st) {
      if (generation != _generation || isDisposed) return;
      _lastStackTrace = st;
      value = GetStatus<T>.error(e);
    }
  }

  /// Builds from the current status. Inside an `Obx`, subscribes it.
  R when<R>({
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error) error,
  }) {
    final status = value;
    if (status is SuccessStatus<T>) return success(status.data);
    if (status is ErrorStatus) {
      return error((status as ErrorStatus).error ?? 'error');
    }
    return loading();
  }
}
