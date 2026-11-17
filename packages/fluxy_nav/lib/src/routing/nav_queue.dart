import 'dart:async';

/// Runs navigations one at a time, in call order.
///
/// When nothing is queued, a task starts right away, so a navigation that
/// needs no asynchronous redirect changes the stack before the call
/// returns. A task started while another is still running (waiting for a
/// redirect, or calling a navigation from inside one) waits for it.
class NavQueue {
  int _pending = 0;
  Future<void> _tail = Future<void>.value();

  /// Whether no task is running or waiting.
  bool get isIdle => _pending == 0;

  FutureOr<T> run<T>(FutureOr<T> Function() task) {
    if (_pending == 0) {
      _pending++;
      final FutureOr<T> result;
      try {
        result = task();
      } catch (_) {
        _pending--;
        rethrow;
      }
      if (result is Future<T>) {
        _tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
          _pending--;
        });
        return result;
      }
      _pending--;
      return result;
    }
    _pending++;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        _pending--;
      }
    });
    return completer.future;
  }
}
