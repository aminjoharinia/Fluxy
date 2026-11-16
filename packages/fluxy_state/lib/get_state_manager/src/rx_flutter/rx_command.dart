import 'dart:async';

import '../../../get_rx/src/rx_types/rx_types.dart';
import 'rx_notifier.dart';

/// What [RxCommand.run] does when it is called while a run is in flight.
enum CommandMode {
  /// Ignore the new call and return the run in flight (a submit button
  /// tapped twice sends once).
  droppable,

  /// Start the new run; the older one's result is ignored, so a slow older
  /// response never overwrites a newer one (search-as-you-type).
  restartable,

  /// Queue the new run; runs go one after another, in call order.
  sequential,

  /// Run at once, alongside the others; the status settles when all are
  /// done.
  concurrent,
}

/// An async action as an Rx of its [GetStatus], with a rule for overlapping
/// calls ([CommandMode], like `bloc_concurrency`'s transformers).
///
/// ```dart
/// final save = RxCommand(() => api.saveProfile(form.value));
/// final search = RxCommand(
///   () => api.search(query.value),
///   mode: CommandMode.restartable,
/// );
///
/// ElevatedButton(onPressed: save.run, child: const Text('Save'));
/// Obx(() => save.isRunning ? const Spinner() : const SizedBox());
/// ```
///
/// - Its value starts as [EmptyStatus] (not run yet), is a [LoadingStatus]
///   while it runs (keeping the last data, see [GetStatus.isRefreshing]),
///   then a [SuccessStatus] or an [ErrorStatus] (also keeping the last
///   data).
/// - [run] never throws: it completes with the status of that call (for a
///   dropped call, the run in flight).
/// - [cancel] ignores the results of runs in flight and skips queued ones.
class RxCommand<T> extends Rx<GetStatus<T>> {
  RxCommand(this._action, {this.mode = CommandMode.droppable})
      : super(EmptyStatus<T>());

  final Future<T> Function() _action;

  /// The rule for overlapping calls.
  final CommandMode mode;

  int _generation = 0;
  int _inFlight = 0;
  Future<GetStatus<T>>? _current;
  Future<void> _tail = Future<void>.value();

  /// Whether a run is in flight or queued. Inside an `Obx`, subscribes it.
  bool get isRunning => value is LoadingStatus<T>;

  /// Runs the action, following [mode]. See [CommandMode].
  Future<GetStatus<T>> run() {
    if (isDisposed) return Future<GetStatus<T>>.value(peek);
    switch (mode) {
      case CommandMode.droppable:
        final inFlight = _current;
        if (inFlight != null) return inFlight;
        final future = _start(_generation);
        _current = future;
        future.whenComplete(() {
          if (identical(_current, future)) _current = null;
        });
        return future;
      case CommandMode.restartable:
        return _start(++_generation);
      case CommandMode.sequential:
        final generation = _generation;
        // Nothing in flight: start now (not a microtask later).
        final idle = _inFlight == 0;
        _enter();
        final future = idle
            ? _execute(generation)
            : _tail.then((_) => _execute(generation));
        _tail = future;
        return future;
      case CommandMode.concurrent:
        return _start(_generation);
    }
  }

  /// Ignores the results of the runs in flight and skips the queued ones.
  /// The status goes back to the last data ([SuccessStatus]) or to
  /// [EmptyStatus] if there was none.
  void cancel() {
    if (isDisposed) return;
    _generation++;
    _current = null;
    final status = peek;
    if (status is LoadingStatus<T>) {
      value = status.hasData
          ? GetStatus<T>.success(status.data as T)
          : EmptyStatus<T>();
    }
  }

  Future<GetStatus<T>> _start(int generation) {
    _enter();
    return _execute(generation);
  }

  void _enter() {
    _inFlight++;
    final status = peek;
    if (status is! LoadingStatus<T>) value = status.toLoading();
  }

  Future<GetStatus<T>> _execute(int generation) async {
    // A queued run cancelled before it started: skip the action.
    if (generation != _generation) {
      _inFlight--;
      return peek;
    }
    GetStatus<T> result;
    try {
      result = GetStatus<T>.success(await _action());
    } catch (e, st) {
      result = GetStatus<T>.error(e, st);
    }
    _inFlight--;
    if (isDisposed || generation != _generation) return result;

    final settled = _inFlight == 0 || mode == CommandMode.restartable;
    switch (result) {
      case SuccessStatus(:final data):
        value = settled ? result : LoadingStatus<T>.withData(data);
      case ErrorStatus(:final error, :final stackTrace):
        // Keep the last data with the error; while other runs are still in
        // flight, stay loading.
        if (settled) value = peek.toError(error, stackTrace);
      case LoadingStatus() || EmptyStatus():
        break;
    }
    return result;
  }
}
