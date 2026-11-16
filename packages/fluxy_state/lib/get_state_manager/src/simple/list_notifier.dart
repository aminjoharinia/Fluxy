import 'dart:collection';

import 'package:flutter/foundation.dart';

// This callback remove the listener on addListener function
typedef Disposer = void Function();

// replacing StateSetter, return if the Widget is mounted for extra validation.
// if it brings overhead the extra call,
typedef GetStateUpdate = void Function();

class ListNotifier extends Listenable
    with ListNotifierSingleMixin, ListNotifierGroupMixin {}

/// A Notifier with single listeners
class ListNotifierSingle = ListNotifier with ListNotifierSingleMixin;

/// A notifier with group of listeners identified by id
class ListNotifierGroup = ListNotifier with ListNotifierGroupMixin;

/// This mixin add to Listenable the addListener, removerListener and
/// containsListener implementation
mixin ListNotifierSingleMixin on Listenable {
  List<GetStateUpdate>? _updaters = <GetStateUpdate>[];

  /// The list a notify is walking right now. Adding or removing a listener
  /// while it is walked copies [_updaters] first, so a notify needs no copy
  /// of its own (it used to copy the list on every change).
  List<GetStateUpdate>? _notifying;

  List<GetStateUpdate>? _writableUpdaters() {
    final list = _updaters;
    if (list != null && identical(list, _notifying)) {
      return _updaters = List.of(list);
    }
    return list;
  }

  @override
  Disposer addListener(GetStateUpdate listener) {
    assert(_debugAssertNotDisposed());
    _writableUpdaters()!.add(listener);
    return () => _writableUpdaters()?.remove(listener);
  }

  bool containsListener(GetStateUpdate listener) {
    return _updaters?.contains(listener) ?? false;
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    _writableUpdaters()!.remove(listener);
  }

  @protected
  void refresh() {
    assert(_debugAssertNotDisposed());
    _notifyUpdate();
  }

  @protected
  void reportRead() {
    Notifier.instance.read(this);
  }

  @protected
  void reportAdd(VoidCallback disposer) {
    Notifier.instance.add(disposer);
  }

  int _reactiveVersion = 0;

  /// Goes up each time this notifier notifies (or would, inside a batch).
  /// Derived values (`Computed`) and effects compare it with the version
  /// they saw when they last read this notifier, to know whether it changed.
  int get reactiveVersion => _reactiveVersion;

  /// Whether a notification of this notifier is a change of app state (an
  /// Rx write). Derived values return false: their changes follow from a
  /// source change that was already counted.
  @protected
  bool get bumpsGlobalVersion => true;

  void _notifyUpdate() {
    _reactiveVersion++;
    final notifier = Notifier.instance;
    if (bumpsGlobalVersion) notifier._globalVersion++;
    if (notifier._batchDepth > 0) {
      // Inside [Notifier.batch]: notify once, when the outermost batch ends.
      notifier._pending.add(this);
      return;
    }
    _notifyUpdateNow();
  }

  void _notifyUpdateNow() {
    final list = _updaters;
    if (list == null || list.isEmpty) return;
    // Listeners added or removed during this notify go to a copy (see
    // [_writableUpdaters]), so this walk sees the list as it was when the
    // notify started, as before.
    final previous = _notifying;
    _notifying = list;
    final notifier = Notifier.instance;
    notifier._depth++;
    try {
      for (var i = 0; i < list.length; i++) {
        // A listener that throws is reported and the others still run (as
        // with ChangeNotifier). It used to stop the loop, so every later
        // listener (other Obx, workers, Computed) missed the change.
        try {
          list[i]();
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'fluxy_state',
            context: ErrorDescription(
                'while notifying the listeners of a $runtimeType'),
          ));
        }
      }
    } finally {
      _notifying = previous;
      // Effects scheduled by this notify run once it (and any notify it
      // caused) is over, so each runs once and sees the final values.
      if (--notifier._depth == 0) notifier._runReactionsIfIdle();
    }
  }

  bool get isDisposed => _updaters == null;

  bool _debugAssertNotDisposed() {
    assert(() {
      if (isDisposed) {
        throw FlutterError('''A $runtimeType was used after being disposed.\n
'Once you have called dispose() on a $runtimeType, it can no longer be used.''');
      }
      return true;
    }());
    return true;
  }

  int get listenersLength {
    assert(_debugAssertNotDisposed());
    return _updaters!.length;
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _updaters = null;
  }
}

mixin ListNotifierGroupMixin on Listenable {
  HashMap<Object?, ListNotifierSingleMixin>? _updatersGroupIds =
      HashMap<Object?, ListNotifierSingleMixin>();

  void _notifyGroupUpdate(Object id) {
    if (_updatersGroupIds!.containsKey(id)) {
      _updatersGroupIds![id]!._notifyUpdate();
    }
  }

  @protected
  void notifyGroupChildrens(Object id) {
    assert(_debugAssertNotDisposed());
    // Created on demand: reading an id nothing has registered yet used to
    // crash on a null check.
    Notifier.instance.read(_updatersGroupIds![id] ??= ListNotifierSingle());
  }

  bool containsId(Object id) {
    return _updatersGroupIds?.containsKey(id) ?? false;
  }

  @protected
  void refreshGroup(Object id) {
    assert(_debugAssertNotDisposed());
    _notifyGroupUpdate(id);
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_updatersGroupIds == null) {
        throw FlutterError('''A $runtimeType was used after being disposed.\n
'Once you have called dispose() on a $runtimeType, it can no longer be used.''');
      }
      return true;
    }());
    return true;
  }

  void removeListenerId(Object id, VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    if (_updatersGroupIds!.containsKey(id)) {
      _updatersGroupIds![id]!.removeListener(listener);
    }
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _updatersGroupIds?.forEach((key, value) => value.dispose());
    _updatersGroupIds = null;
  }

  Disposer addListenerId(Object? key, GetStateUpdate listener) {
    _updatersGroupIds![key] ??= ListNotifierSingle();
    return _updatersGroupIds![key]!.addListener(listener);
  }

  /// To dispose an [id] from future updates(), this ids are registered
  /// by `GetBuilder()` or similar, so is a way to unlink the state change with
  /// the Widget from the Controller.
  void disposeId(Object id) {
    _updatersGroupIds?.remove(id)?.dispose();
  }
}

class Notifier {
  Notifier._();

  static Notifier? _instance;
  static Notifier get instance => _instance ??= Notifier._();

  NotifyData? _notifyData;

  int _batchDepth = 0;
  final _pending = LinkedHashSet<ListNotifierSingleMixin>.identity();

  /// How many notifies are running (nested: a listener that writes an Rx).
  int _depth = 0;

  int _globalVersion = 0;

  /// Goes up on every Rx change. A derived value that last checked its
  /// sources at the current global version is known to be up to date
  /// without looking at them.
  int get globalVersion => _globalVersion;

  final _reactions = LinkedHashSet<ScheduledReaction>.identity();
  bool _runningReactions = false;

  /// How many rounds of effects re-triggering effects are allowed before
  /// it is treated as a loop.
  static const maxReactionRounds = 100;

  /// True while code runs inside an observer build ([Obx], [GetX]), so reads
  /// of an Rx subscribe that observer.
  bool get isTracking => _notifyData != null;

  /// True inside [batch].
  bool get isBatching => _batchDepth > 0;

  /// Runs [reaction] once the current notify / batch is over, or now when
  /// nothing is notifying. Scheduling it again before it ran is a no-op, so
  /// a reaction runs once however many of its sources changed.
  void schedule(ScheduledReaction reaction) {
    _reactions.add(reaction);
    _runReactionsIfIdle();
  }

  void _runReactionsIfIdle() {
    if (_depth == 0 && _batchDepth == 0 && _reactions.isNotEmpty) {
      _runReactions();
    }
  }

  void _runReactions() {
    // Reactions scheduled while these run (an effect that writes) are run
    // by this loop in the next round, not nested.
    if (_runningReactions) return;
    _runningReactions = true;
    try {
      var rounds = 0;
      while (_reactions.isNotEmpty) {
        if (++rounds > maxReactionRounds) {
          _reactions.clear();
          throw StateError(
              'Effects kept triggering each other for $maxReactionRounds '
              'rounds. An effect probably writes a value it reads.');
        }
        final list = _reactions.toList(growable: false);
        _reactions.clear();
        for (final reaction in list) {
          reaction.runScheduled();
        }
      }
    } finally {
      _runningReactions = false;
    }
  }

  void add(VoidCallback listener) {
    _notifyData?.disposers.add(listener);
  }

  void read(ListNotifierSingleMixin updaters) {
    final data = _notifyData;
    if (data == null) return;
    final subscriptions = data.subscriptions;
    if (subscriptions != null) {
      subscriptions._read(updaters, data.updater);
      return;
    }
    final listener = data.updater;
    if (!updaters.containsListener(listener)) {
      updaters.addListener(listener);
      add(() => updaters.removeListener(listener));
    }
  }

  T append<T>(NotifyData data, T Function() builder) {
    final previous = _notifyData;
    _notifyData = data;
    data.subscriptions?._begin();
    try {
      final result = builder();
      // Only after a build that finished: a build that threw keeps its old
      // subscriptions, so the widget still rebuilds once the error is fixed.
      data.subscriptions?._end();
      if (data.throwException && data._isEmpty) {
        throw const ObxError();
      }
      return result;
    } finally {
      _notifyData = previous;
    }
  }

  /// Runs [fn] without subscribing the current observer to the Rx values it
  /// reads. See also `Rx.peek`.
  T untrack<T>(T Function() fn) {
    final previous = _notifyData;
    _notifyData = null;
    try {
      return fn();
    } finally {
      _notifyData = previous;
    }
  }

  /// Runs [fn] and holds every Rx / notifier change made inside it until the
  /// outermost [batch] returns. Then each changed notifier notifies **once**,
  /// so listeners, workers and streams see only the final value.
  ///
  /// Batches can nest. If [fn] throws, the changes already made are still
  /// notified.
  T batch<T>(T Function() fn) {
    _batchDepth++;
    try {
      return fn();
    } finally {
      if (--_batchDepth == 0) _flush();
    }
  }

  void _flush() {
    // Counted as one notify, so effects run once after every held change
    // went out (not once per changed Rx). Listener errors are reported by
    // each notify, so one failing listener does not hold back the others.
    _depth++;
    try {
      while (_pending.isNotEmpty) {
        final list = _pending.toList(growable: false);
        _pending.clear();
        for (final notifier in list) {
          if (notifier.isDisposed) continue;
          notifier._notifyUpdateNow();
        }
      }
    } finally {
      _depth--;
    }
    _runReactionsIfIdle();
  }
}

class NotifyData {
  NotifyData(
      {required this.updater,
      required this.disposers,
      this.subscriptions,
      this.throwException = true});
  final GetStateUpdate updater;

  /// Cleanup callbacks owned by the observer (for example `bindStream`
  /// subscriptions). Without [subscriptions], Rx subscriptions go here too
  /// and are only removed on unmount.
  final List<VoidCallback> disposers;

  /// When set, the observer's Rx subscriptions are kept in sync with what
  /// each build reads; see [ObserverSubscriptions] and [TrackedSources].
  final ReadTracker? subscriptions;
  final bool throwException;

  bool get _isEmpty =>
      disposers.isEmpty && (subscriptions == null || subscriptions!.isEmpty);
}

/// The notifiers (Rx values) an observer widget read on its last build, each
/// with the disposer that unsubscribes it.
///
/// After every build, notifiers that were not read again are unsubscribed, so
/// an [Obx] whose `if` stops reading an Rx no longer rebuilds when that Rx
/// changes. A notifier read on consecutive builds keeps its one subscription.
///
/// Keyed by identity, because `Rx` overrides `==` to compare values.
class ObserverSubscriptions extends ReadTracker {
  final _active = LinkedHashMap<ListNotifierSingleMixin, Disposer>.identity();
  final _seen = HashSet<ListNotifierSingleMixin>.identity();

  int get length => _active.length;
  @override
  bool get isEmpty => _active.isEmpty;

  /// Whether [notifier] is currently subscribed.
  bool contains(ListNotifierSingleMixin notifier) =>
      _active.containsKey(notifier);

  @override
  void _begin() => _seen.clear();

  @override
  void _read(ListNotifierSingleMixin notifier, GetStateUpdate updater) {
    if (!_seen.add(notifier)) return;
    if (!_active.containsKey(notifier)) {
      _active[notifier] = notifier.addListener(updater);
    }
  }

  @override
  void _end() {
    if (_seen.length == _active.length) return;
    _active.removeWhere((notifier, disposer) {
      if (_seen.contains(notifier)) return false;
      disposer();
      return true;
    });
  }

  void dispose() {
    for (final disposer in _active.values) {
      disposer();
    }
    _active.clear();
    _seen.clear();
  }
}
class ObxError {
  const ObxError();
  @override
  String toString() {
    return """
      [Get] the improper use of a GetX has been detected. 
      You should only use GetX or Obx for the specific widget that will be updated.
      If you are seeing this error, you probably did not insert any observable variables into GetX/Obx 
      or insert them outside the scope that GetX considers suitable for an update 
      (example: GetX => HeavyWidget => variableObservable).
      If you need to update a parent widget and a child widget, wrap each one in an Obx/GetX.
      """;
  }
}

/// Records what an observer reads while it runs. See [ObserverSubscriptions]
/// (widgets) and [TrackedSources] (`Computed`, `Effect`).
abstract class ReadTracker {
  bool get isEmpty;
  void _begin();
  void _read(ListNotifierSingleMixin notifier, GetStateUpdate updater);
  void _end();
}

/// Something [Notifier.schedule] runs once the current notify is over
/// (an `Effect`).
abstract class ScheduledReaction {
  void runScheduled();
}

class _Source {
  _Source(this.notifier);
  final ListNotifierSingleMixin notifier;

  /// [ListNotifierSingleMixin.reactiveVersion] when it was last read.
  int version = 0;

  /// The run that last read it.
  int run = 0;
  Disposer? disposer;
}

/// The sources a derived value (`Computed`) or an `Effect` read on its last
/// run, in read order, with the version each had when it was read.
///
/// - [changed] tells, without running anything, whether any source moved on
///   since. A source that is itself a `Computed` brings itself up to date
///   first, so the answer is never based on a stale intermediate value.
/// - While [listen]ing, every source is subscribed; [unlisten] drops the
///   subscriptions but keeps the record, so a `Computed` nobody listens to
///   can still tell whether it needs to recompute.
class TrackedSources extends ReadTracker {
  List<_Source> _list = <_Source>[];
  final _byNotifier = HashMap<ListNotifierSingleMixin, _Source>.identity();
  List<_Source>? _next;
  int _run = 0;
  GetStateUpdate? _listener;

  int get length => _list.length;
  @override
  bool get isEmpty => _list.isEmpty;
  bool get isListening => _listener != null;

  /// Whether [notifier] was read on the last run.
  bool contains(ListNotifierSingleMixin notifier) =>
      _byNotifier.containsKey(notifier);

  /// Whether a source read on the last run changed since.
  bool get changed {
    final list = _list;
    for (var i = 0; i < list.length; i++) {
      final source = list[i];
      if (source.notifier.reactiveVersion != source.version) return true;
    }
    return false;
  }

  /// Subscribes [listener] to every source, now and on later runs.
  void listen(GetStateUpdate listener) {
    if (_listener != null) return;
    _listener = listener;
    for (final source in _list) {
      if (!source.notifier.isDisposed) {
        source.disposer = source.notifier.addListener(listener);
      }
    }
  }

  /// Drops the subscriptions, keeps the record of what was read.
  void unlisten() {
    _listener = null;
    for (final source in _list) {
      source.disposer?.call();
      source.disposer = null;
    }
  }

  /// Runs [fn] and records what it reads. If [fn] throws, the sources read
  /// before the throw are added to the previous ones (so a change of any of
  /// them runs it again) and the error is rethrown.
  T track<T>(T Function() fn) {
    final notifier = Notifier.instance;
    final previous = notifier._notifyData;
    notifier._notifyData = NotifyData(
      updater: _ignore,
      disposers: <Disposer>[],
      subscriptions: this,
      throwException: false,
    );
    _begin();
    try {
      final result = fn();
      _end();
      return result;
    } catch (_) {
      _endAfterError();
      rethrow;
    } finally {
      notifier._notifyData = previous;
    }
  }

  static void _ignore() {}

  @override
  void _begin() {
    _run++;
    _next = <_Source>[];
  }

  @override
  void _read(ListNotifierSingleMixin notifier, GetStateUpdate updater) {
    final next = _next;
    if (next == null) return;
    var source = _byNotifier[notifier];
    if (source == null) {
      source = _byNotifier[notifier] = _Source(notifier);
      final listener = _listener;
      if (listener != null && !notifier.isDisposed) {
        source.disposer = notifier.addListener(listener);
      }
    } else if (source.run == _run) {
      return;
    }
    source.run = _run;
    next.add(source);
    // Read last: for a Computed source this brings it up to date.
    source.version = notifier.reactiveVersion;
  }

  @override
  void _end() {
    final next = _next!;
    _next = null;
    for (final source in _list) {
      if (source.run != _run) {
        source.disposer?.call();
        _byNotifier.remove(source.notifier);
      }
    }
    _list = next;
  }

  void _endAfterError() {
    final next = _next!;
    _next = null;
    for (final source in _list) {
      if (source.run != _run) next.add(source);
    }
    _list = next;
  }

  void dispose() {
    unlisten();
    _list = <_Source>[];
    _byNotifier.clear();
  }
}
