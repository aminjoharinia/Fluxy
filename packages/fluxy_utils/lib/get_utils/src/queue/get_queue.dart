import 'dart:async';

class GetMicrotask {
  int _version = 0;
  int _microtask = 0;

  int get microtask => _microtask;
  int get version => _version;

  void exec(Function callback) {
    if (_microtask == _version) {
      _microtask++;
      scheduleMicrotask(() {
        _version++;
        _microtask = _version;
        callback();
      });
    }
  }
}

/// Thrown into the futures of jobs that [GetQueue.cancelAllJobs] removed
/// before they started.
class GetQueueCancelledException implements Exception {
  const GetQueueCancelledException();

  @override
  String toString() => 'GetQueueCancelledException: the job was cancelled';
}

/// Runs jobs one after the other, in the order they were added.
class GetQueue {
  final List<_Item> _queue = [];
  bool _active = false;

  Future<T> add<T>(FutureOr<T> Function() job) {
    final completer = Completer<T>();
    _queue.add(_Item<T>(completer, job));
    _check();
    return completer.future;
  }

  /// Drops the jobs that haven't started. Their futures fail with
  /// [GetQueueCancelledException] (they used to never complete). A job
  /// already running is not stopped.
  void cancelAllJobs() {
    final cancelled = List.of(_queue);
    _queue.clear();
    for (final item in cancelled) {
      item.cancel();
    }
  }

  void _check() async {
    if (!_active && _queue.isNotEmpty) {
      _active = true;
      final item = _queue.removeAt(0);
      // Any error, not only an Exception: an Error used to leave the queue
      // marked as running forever, so no later job ever ran.
      await item.run();
      _active = false;
      _check();
    }
  }
}

class _Item<T> {
  final Completer<T> completer;
  final FutureOr<T> Function() job;

  _Item(this.completer, this.job);

  Future<void> run() async {
    try {
      completer.complete(await job());
    } catch (e, s) {
      completer.completeError(e, s);
    }
  }

  void cancel() {
    // Nobody may be listening (a fire-and-forget add); don't report the
    // cancellation as an uncaught error then. Listeners still get it.
    completer.future.ignore();
    completer.completeError(const GetQueueCancelledException());
  }
}
