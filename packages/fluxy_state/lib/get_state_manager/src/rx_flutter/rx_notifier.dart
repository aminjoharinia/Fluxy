import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

import '../simple/list_notifier.dart';

extension _Empty on Object {
  bool _isEmpty() {
    final val = this;
    // if (val == null) return true;
    var result = false;
    if (val is Iterable) {
      result = val.isEmpty;
    } else if (val is String) {
      result = val.trim().isEmpty;
    } else if (val is Map) {
      result = val.isEmpty;
    }
    return result;
  }
}

mixin StateMixin<T> on ListNotifier {
  T? _value;
  FluxyStatus<T>? _status;

  int _futurizeGeneration = 0;

  void _fillInitialStatus() {
    _status = (_value == null || _value!._isEmpty())
        ? FluxyStatus<T>.loading()
        : FluxyStatus<T>.success(_value as T);
  }

  FluxyStatus<T> get status {
    reportRead();
    return _status ??= FluxyStatus<T>.loading();
  }

  T get state => value;

  set status(FluxyStatus<T> newStatus) {
    // Compared without reportRead, so setting the status inside a build
    // does not subscribe that build.
    // A success always notifies: its data may be the same object edited in
    // place (the deep comparison saw it as unchanged and skipped the
    // update), and comparing large data on every set is costly.
    if (newStatus is! SuccessStatus<T> &&
        newStatus == (_status ??= FluxyStatus<T>.loading())) {
      return;
    }
    _status = newStatus;
    if (newStatus is SuccessStatus<T>) {
      _value = newStatus.data;
    }
    refresh();
  }

  @protected
  T get value {
    reportRead();
    return _value as T;
  }

  @protected
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    refresh();
  }

  @protected
  void change(FluxyStatus<T> status) {
    this.status = status;
  }

  void setSuccess(T data) {
    change(FluxyStatus<T>.success(data));
  }

  /// An error that keeps the data shown so far (see [FluxyStatus.toError]).
  void setError(Object error, [StackTrace? stackTrace]) {
    change(_currentStatus.toError(error, stackTrace));
  }

  /// Loading that keeps the data shown so far (see
  /// [FluxyStatus.isRefreshing]).
  void setLoading() {
    change(_currentStatus.toLoading());
  }

  FluxyStatus<T> get _currentStatus => _status ??= FluxyStatus<T>.loading();

  void setEmpty() {
    change(FluxyStatus<T>.empty());
  }

  /// Runs [body] and moves through loading, then success / empty / error.
  ///
  /// - Only the newest call counts: a slower, older call that finishes later
  ///   is ignored.
  /// - Each result notifies once.
  /// - The error keeps the object that was thrown; if [errorMessage] is
  ///   given, it is used instead.
  void futurize(Future<T> Function() body,
      {T? initialData, String? errorMessage, bool useEmpty = true}) {
    final generation = ++_futurizeGeneration;
    _value ??= initialData;
    status = _currentStatus.toLoading();
    Future<T>.sync(body).then((newValue) {
      if (generation != _futurizeGeneration || isDisposed) return;
      if ((newValue == null || newValue._isEmpty()) && useEmpty) {
        status = FluxyStatus<T>.empty();
      } else {
        status = FluxyStatus<T>.success(newValue);
      }
    }, onError: (Object err, StackTrace stackTrace) {
      if (generation != _futurizeGeneration || isDisposed) return;
      status = _currentStatus.toError(errorMessage ?? err, stackTrace);
    });
  }
}

typedef FuturizeCallback<T> = Future<T> Function(VoidCallback fn);

class FluxyListenable<T> extends ListNotifierSingle implements RxInterface<T> {
  FluxyListenable(T val) : _value = val;

  StreamController<T>? _controller;

  Disposer? _removeStreamListener;

  /// The broadcast stream behind `listen`, `stream`, `ever` and the other
  /// workers. It listens to this Rx while the stream has subscribers and
  /// stops when the last one cancels; a later subscriber hooks it up again.
  /// (Before, the stream was unhooked on the first "last cancel" and never
  /// hooked back, so `ever` on an Rx whose workers had all been disposed once
  /// never fired again.)
  StreamController<T> get subject {
    return _controller ??= StreamController<T>.broadcast(
      onListen: () {
        if (isDisposed) return;
        _removeStreamListener ??= addListener(_streamListener);
      },
      onCancel: () {
        _removeStreamListener?.call();
        _removeStreamListener = null;
      },
    );
  }

  void _streamListener() {
    _controller?.add(_value);
  }

  @override
  @mustCallSuper
  void close() {
    _removeStreamListener?.call();
    _removeStreamListener = null;
    _controller?.close();
    dispose();
  }

  Stream<T> get stream {
    return subject.stream;
  }

  T _value;

  @override
  @pragma('vm:prefer-inline')
  T get value {
    reportRead();
    return _value;
  }

  /// The current value, **without** subscribing the observer that is
  /// building ([Obx], [FluxyX]). Use it inside mutators and when a build needs
  /// a value but should not rebuild when it changes.
  T get peek => _value;

  void _notify() {
    refresh();
  }

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _notify();
  }

  /// Stores [newValue] and notifies, without comparing it with the current
  /// value: for a setter that compared already (`Rx.value`), so a costly
  /// `==` runs once per write.
  @protected
  void setValueUnchecked(T newValue) {
    _value = newValue;
    _notify();
  }

  /// `rx(v)` sets the value and returns it, so an Rx can be passed where a
  /// `ValueChanged<T>` is expected: `TextField(onChanged: myText)`.
  /// `rxn(null)` sets a nullable Rx to null.
  ///
  /// The argument is required and typed: `count('abc')` and `count(null)`
  /// on a non-nullable Rx are compile errors. To read, use [value] (or
  /// `peek`); `rx()` no longer reads.
  T call(T v) {
    value = v;
    return peek;
  }

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError ?? false,
      );

  @override
  String toString() => value.toString();
}

class Value<T> extends ListNotifier
    with StateMixin<T>
    implements ValueListenable<T?> {
  Value(T val) {
    _value = val;
    _fillInitialStatus();
  }

  @override
  T get value {
    reportRead();
    return _value as T;
  }

  /// The current value without subscribing the building observer.
  T get peek => _value as T;

  @override
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    refresh();
  }

  /// `rx(v)` sets the value and returns it, so an Rx can be passed where a
  /// `ValueChanged<T>` is expected: `TextField(onChanged: myText)`.
  /// `rxn(null)` sets a nullable Rx to null.
  ///
  /// The argument is required and typed: `count('abc')` and `count(null)`
  /// on a non-nullable Rx are compile errors. To read, use [value] (or
  /// `peek`); `rx()` no longer reads.
  T call(T v) {
    value = v;
    return peek;
  }

  /// If [fn] returns the same object it was given (it edited it in place),
  /// listeners are still notified.
  void update(T Function(T? value) fn) {
    final current = peek;
    final next = fn(current);
    if (identical(next, current)) {
      refresh();
    } else {
      value = next;
    }
  }

  @override
  String toString() => value.toString();

  dynamic toJson() => (value as dynamic)?.toJson();
}

/// FluxyNotifier has a native status and state implementation, with the
/// Get Lifecycle
abstract class FluxyNotifier<T> extends Value<T> with FluxyLifeCycleMixin {
  FluxyNotifier(super.initial);
}

extension StateExt<T> on StateMixin<T> {
  /// Builds from [status]. While reloading with data from before (see
  /// [FluxyStatus.isRefreshing]) it keeps showing [widget] unless
  /// [skipLoadingOnRefresh] is false.
  Widget obx(
    NotifierBuilder<T> widget, {
    Widget Function(String? error)? onError,
    Widget? onLoading,
    Widget? onEmpty,
    bool skipLoadingOnRefresh = true,
  }) {
    return Observer(builder: (context) {
      return switch (status) {
        SuccessStatus() => widget(value),
        LoadingStatus(hasData: true) when skipLoadingOnRefresh =>
          widget(value),
        LoadingStatus() =>
          onLoading ?? const Center(child: CircularProgressIndicator()),
        ErrorStatus() => onError != null
            ? onError(status.errorMessage)
            : Center(child: Text('A error occurred: ${status.errorMessage}')),
        // Also can be widget(null); but is risky
        EmptyStatus() => onEmpty ?? const SizedBox.shrink(),
      };
    });
  }
}

typedef NotifierBuilder<T> = Widget Function(T state);

/// The state of async data: [LoadingStatus], [SuccessStatus], [ErrorStatus]
/// or [EmptyStatus].
///
/// It is `sealed`, so a `switch` on it must handle every case (the analyzer
/// reports a missing one):
///
/// ```dart
/// final widget = switch (controller.status) {
///   SuccessStatus(:final data) => RoomList(data),
///   LoadingStatus() => const Spinner(),
///   ErrorStatus(:final error) => Text('$error'),
///   EmptyStatus() => const Text('No rooms'),
/// };
/// ```
///
/// Like Riverpod's `AsyncValue`, a loading or error status can carry the
/// data of the last success ([hasData], [data], [isRefreshing]), so a reload
/// or a failed refresh can keep showing the old content. [toLoading] and
/// [toError] build them from the current status.
sealed class FluxyStatus<T> with Equality {
  const FluxyStatus();

  factory FluxyStatus.loading() => LoadingStatus<T>();

  factory FluxyStatus.error(Object error, [StackTrace? stackTrace]) =>
      ErrorStatus<T>(error, stackTrace: stackTrace);

  factory FluxyStatus.empty() => EmptyStatus<T>();

  factory FluxyStatus.success(T data) => SuccessStatus<T>(data);

  /// Whether data is available: this success's data, or the data a loading
  /// / error status carried over from the last success.
  bool get hasData;

  /// The data of this success, or the data carried over; null if none.
  T? get data;

  /// Loading while showing data from before (a refresh).
  bool get isRefreshing => this is LoadingStatus<T> && hasData;

  /// A loading status that keeps this status's data.
  LoadingStatus<T> toLoading() =>
      hasData ? LoadingStatus<T>.withData(data as T) : LoadingStatus<T>();

  /// An error status that keeps this status's data.
  ErrorStatus<T> toError(Object error, [StackTrace? stackTrace]) => hasData
      ? ErrorStatus<T>.withData(error, data as T, stackTrace: stackTrace)
      : ErrorStatus<T>(error, stackTrace: stackTrace);
}

class LoadingStatus<T> extends FluxyStatus<T> {
  const LoadingStatus()
      : hasData = false,
        _data = null;

  /// Loading again while keeping the data from before.
  const LoadingStatus.withData(T data)
      : hasData = true,
        _data = data;

  @override
  final bool hasData;
  final T? _data;

  @override
  T? get data => _data;

  @override
  List get props => [hasData, _data];
}

class SuccessStatus<T> extends FluxyStatus<T> {
  @override
  final T data;

  const SuccessStatus(this.data);

  @override
  bool get hasData => true;

  @override
  List get props => [data];
}

class ErrorStatus<T> extends FluxyStatus<T> {
  const ErrorStatus(this.error, {this.stackTrace})
      : hasData = false,
        _data = null;

  /// Failed while keeping the data from before.
  const ErrorStatus.withData(this.error, T data, {this.stackTrace})
      : hasData = true,
        _data = data;

  final Object error;
  final StackTrace? stackTrace;

  @override
  final bool hasData;
  final T? _data;

  @override
  T? get data => _data;

  @override
  List get props => [error, hasData, _data];
}

class EmptyStatus<T> extends FluxyStatus<T> {
  const EmptyStatus();

  @override
  bool get hasData => false;

  @override
  T? get data => null;

  @override
  List get props => [];
}

extension StatusDataExt<T> on FluxyStatus<T> {
  bool get isLoading => this is LoadingStatus;

  bool get isSuccess => this is SuccessStatus;

  bool get isError => this is ErrorStatus;

  bool get isEmpty => this is EmptyStatus;

  /// The error of an [ErrorStatus], else null.
  Object? get error => switch (this) {
        ErrorStatus(:final error) => error,
        _ => null,
      };

  /// The error as text ('' if not an error).
  String get errorMessage => switch (this) {
        ErrorStatus(:final error) => error is String ? error : '$error',
        _ => '',
      };
}
