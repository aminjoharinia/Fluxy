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
  GetStatus<T>? _status;

  int _futurizeGeneration = 0;

  void _fillInitialStatus() {
    _status = (_value == null || _value!._isEmpty())
        ? GetStatus<T>.loading()
        : GetStatus<T>.success(_value as T);
  }

  GetStatus<T> get status {
    reportRead();
    return _status ??= GetStatus<T>.loading();
  }

  T get state => value;

  set status(GetStatus<T> newStatus) {
    // Compared without reportRead, so setting the status inside a build
    // does not subscribe that build.
    // A success always notifies: its data may be the same object edited in
    // place (the deep comparison saw it as unchanged and skipped the
    // update), and comparing large data on every set is costly.
    if (newStatus is! SuccessStatus<T> &&
        newStatus == (_status ??= GetStatus<T>.loading())) {
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
  void change(GetStatus<T> status) {
    this.status = status;
  }

  void setSuccess(T data) {
    change(GetStatus<T>.success(data));
  }

  void setError(Object error) {
    change(GetStatus<T>.error(error));
  }

  void setLoading() {
    change(GetStatus<T>.loading());
  }

  void setEmpty() {
    change(GetStatus<T>.empty());
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
    status = GetStatus<T>.loading();
    Future<T>.sync(body).then((newValue) {
      if (generation != _futurizeGeneration || isDisposed) return;
      if ((newValue == null || newValue._isEmpty()) && useEmpty) {
        status = GetStatus<T>.empty();
      } else {
        status = GetStatus<T>.success(newValue);
      }
    }, onError: (Object err) {
      if (generation != _futurizeGeneration || isDisposed) return;
      status = GetStatus<T>.error(errorMessage ?? err);
    });
  }
}

typedef FuturizeCallback<T> = Future<T> Function(VoidCallback fn);

typedef VoidCallback = void Function();

class GetListenable<T> extends ListNotifierSingle implements RxInterface<T> {
  GetListenable(T val) : _value = val;

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
  T get value {
    reportRead();
    return _value;
  }

  /// The current value, **without** subscribing the observer that is
  /// building ([Obx], [GetX]). Use it inside mutators and when a build needs
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

/// GetNotifier has a native status and state implementation, with the
/// Get Lifecycle
abstract class GetNotifier<T> extends Value<T> with GetLifeCycleMixin {
  GetNotifier(super.initial);
}

extension StateExt<T> on StateMixin<T> {
  Widget obx(
    NotifierBuilder<T> widget, {
    Widget Function(String? error)? onError,
    Widget? onLoading,
    Widget? onEmpty,
    WidgetBuilder? onCustom,
  }) {
    return Observer(builder: (context) {
      if (status.isLoading) {
        return onLoading ?? const Center(child: CircularProgressIndicator());
      } else if (status.isError) {
        return onError != null
            ? onError(status.errorMessage)
            : Center(child: Text('A error occurred: ${status.errorMessage}'));
      } else if (status.isEmpty) {
        return onEmpty ??
            const SizedBox.shrink(); // Also can be widget(null); but is risky
      } else if (status.isSuccess) {
        return widget(value);
      } else if (status.isCustom) {
        return onCustom?.call(context) ??
            const SizedBox.shrink(); // Also can be widget(null); but is risky
      }
      return widget(value);
    });
  }
}

typedef NotifierBuilder<T> = Widget Function(T state);

abstract class GetStatus<T> with Equality {
  const GetStatus();

  factory GetStatus.loading() => LoadingStatus<T>();

  factory GetStatus.error(Object message) => ErrorStatus<T, Object>(message);

  factory GetStatus.empty() => EmptyStatus<T>();

  factory GetStatus.success(T data) => SuccessStatus<T>(data);

  factory GetStatus.custom() => CustomStatus<T>();
}

class CustomStatus<T> extends GetStatus<T> {
  @override
  List get props => [];
}

class LoadingStatus<T> extends GetStatus<T> {
  @override
  List get props => [];
}

class SuccessStatus<T> extends GetStatus<T> {
  final T data;

  const SuccessStatus(this.data);

  @override
  List get props => [data];
}

class ErrorStatus<T, S> extends GetStatus<T> {
  final S? error;

  const ErrorStatus([this.error]);

  @override
  List get props => [error];
}

class EmptyStatus<T> extends GetStatus<T> {
  @override
  List get props => [];
}

extension StatusDataExt<T> on GetStatus<T> {
  bool get isLoading => this is LoadingStatus;

  bool get isSuccess => this is SuccessStatus;

  bool get isError => this is ErrorStatus;

  bool get isEmpty => this is EmptyStatus;

  bool get isCustom => !isLoading && !isSuccess && !isError && !isEmpty;

  dynamic get error {
    if (this is ErrorStatus) {
      return (this as ErrorStatus).error;
    }
    return null;
  }

  String get errorMessage {
    final isError = this is ErrorStatus;
    if (isError) {
      final err = this as ErrorStatus;
      if (err.error != null) {
        if (err.error is String) {
          return err.error as String;
        }
        return err.error.toString();
      }
    }

    return '';
  }

  T? get data {
    if (this is SuccessStatus<T>) {
      final success = this as SuccessStatus<T>;
      return success.data;
    }
    return null;
  }
}
