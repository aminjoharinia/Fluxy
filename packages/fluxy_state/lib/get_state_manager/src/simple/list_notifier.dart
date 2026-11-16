import 'dart:collection';

import 'package:flutter/foundation.dart';

// This callback remove the listener on addListener function
typedef Disposer = void Function();

// replacing StateSetter, return if the Widget is mounted for extra validation.
// if it brings overhead the extra call,
typedef GetStateUpdate = void Function();

class ListNotifier extends Listenable
    with ListNotifierSingleMixin, ListNotifierGroupMixin {
  /// Runs both mixins' disposal. The group mixin's [dispose] (applied last)
  /// cannot call the single one, so a disposed controller used to keep its
  /// listeners (and `isDisposed` stayed false).
  @override
  void dispose() {
    super.dispose();
    _disposeListeners();
  }
}

/// A Notifier with single listeners
class ListNotifierSingle = ListNotifier with ListNotifierSingleMixin;

/// A notifier with group of listeners identified by id
class ListNotifierGroup = ListNotifier with ListNotifierGroupMixin;

/// This mixin add to Listenable the addListener, removerListener and
/// containsListener implementation
mixin ListNotifierSingleMixin on Listenable {
  /// The listeners, in the order they were added. A removed one leaves a
  /// `null` (a hole) until the list is compacted, so removing never shifts
  /// the others. Null until the first listener (most values are written
  /// before anything listens, or never listened to), and again once
  /// disposed.
  List<_Listener?>? _updaters;

  /// Holes (removed listeners) still in [_updaters]; -1 once disposed (a
  /// field check: hot paths ask [isDisposed], and a `static final` marker
  /// costs a lazy-initialization check on every read).
  int _holes = 0;

  /// The list a notify is walking right now. Adding or removing a listener
  /// while it is walked copies [_updaters] first, so a notify needs no copy
  /// of its own (it used to copy the list on every change).
  List<_Listener?>? _notifying;

  List<_Listener?> _writableUpdaters() {
    final list = _updaters;
    if (list == null) return _updaters = <_Listener?>[];
    if (identical(list, _notifying)) return _updaters = List.of(list);
    return list;
  }

  @override
  Disposer addListener(GetStateUpdate listener) {
    assert(_debugAssertNotDisposed());
    // Release builds: ignored (it would never be called anyway).
    if (isDisposed) return _noop;
    final list = _writableUpdaters();
    final entry = _Listener(listener, list.length);
    list.add(entry);
    return () => _removeEntry(entry);
  }

  static void _noop() {}

  bool containsListener(GetStateUpdate listener) =>
      _indexOfListener(listener) >= 0;

  @override
  void removeListener(VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    final index = _indexOfListener(listener);
    if (index >= 0) _removeEntry(_updaters![index]!);
  }

  /// Where [listener] is in [_updaters], or -1. Only `removeListener` /
  /// `containsListener` search; a disposer knows its entry. Identity first,
  /// from both ends; `==` for a tear-off made again
  /// (`removeListener(obj.method)`).
  int _indexOfListener(GetStateUpdate listener) {
    final list = _updaters;
    if (list == null) return -1;
    var lo = 0, hi = list.length - 1;
    while (lo <= hi) {
      if (identical(list[lo]?.fn, listener)) return lo;
      if (identical(list[hi]?.fn, listener)) return hi;
      lo++;
      hi--;
    }
    for (var i = 0; i < list.length; i++) {
      if (list[i]?.fn == listener) return i;
    }
    return -1;
  }

  /// O(1): the entry knows its index. It used to be a search and a
  /// `removeAt`, which shifts every later listener: 1,000 widgets reading
  /// one value spent most of their unmount there.
  void _removeEntry(_Listener entry) {
    final current = _updaters;
    // No listeners yet, or disposed.
    if (current == null || current.isEmpty) return;
    final index = entry.index;
    // Removed already.
    if (index >= current.length || !identical(current[index], entry)) return;
    final list = _writableUpdaters();
    if (index == list.length - 1) {
      list.removeLast();
      while (list.isNotEmpty && list.last == null) {
        list.removeLast();
        _holes--;
      }
      return;
    }
    list[index] = null;
    // Compacted once holes are the majority: amortized O(1) per removal.
    if (++_holes > 8 && _holes * 2 > list.length) _compact(list);
  }

  /// Drops the holes of [list] (never the list a notify walks: see
  /// [_writableUpdaters]), keeping the order.
  void _compact(List<_Listener?> list) {
    var j = 0;
    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      if (entry == null) continue;
      entry.index = j;
      list[j++] = entry;
    }
    list.length = j;
    _holes = 0;
  }

  @protected
  void refresh() {
    assert(_debugAssertNotDisposed());
    _notifyUpdate();
  }

  @protected
  @pragma('vm:prefer-inline')
  void reportRead() {
    // Outside an observer build there is nothing to record: one static
    // field check, no call.
    if (Notifier._notifyData != null) Notifier._readTracked(this);
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

  /// True for a derived value (`Computed`): it keeps [_reactiveVersion]
  /// itself (see [setDerivedVersion]), passes marks on itself, and its
  /// [reactiveVersion] getter brings it up to date first.
  bool _derived = false;

  /// Called by a derived value (`Computed`) when it is created.
  @protected
  void markAsDerived() => _derived = true;

  /// A derived value sets its version (the one tracked reads record) each
  /// time its result changes. It must be up to date whenever it reports a
  /// read, so that a tracked read can take the version from the field.
  @protected
  void setDerivedVersion(int version) => _reactiveVersion = version;

  /// Whether a notification of this notifier is a change of app state (an
  /// Rx write). Derived values return false: their changes follow from a
  /// source change that was already counted.
  @protected
  bool get bumpsGlobalVersion => !_derived;

  /// Derived values (`Computed`) subscribed to this notifier. They are not
  /// listeners: a change only marks them stale, right away (also inside a
  /// batch), and they recompute when read. See [ReactiveDependent]. Null
  /// when there are none, so a write checks one field.
  List<ReactiveDependent>? _dependents;

  /// How many derived values (`Computed`) are subscribed to it.
  int get dependentsLength => _dependents?.length ?? 0;

  /// Everything subscribed to it: listeners and derived values.
  int get subscribersLength => listenersLength + dependentsLength;

  /// Subscribes a derived value; see [_dependents].
  @protected
  Disposer addDependent(ReactiveDependent dependent) {
    assert(_debugAssertNotDisposed());
    (_dependents ??= <ReactiveDependent>[]).add(dependent);
    return () => removeDependent(dependent);
  }

  @protected
  void removeDependent(ReactiveDependent dependent) {
    final dependents = _dependents;
    if (dependents == null) return;
    dependents.remove(dependent);
    if (dependents.isEmpty) _dependents = null;
  }

  /// Marks every dependent as possibly stale, and theirs, all the way
  /// down (a derived value's result may have changed).
  @protected
  void markDependentsStale() => _markDescendants(this);

  /// Marks everything below [from] as maybe stale, depth first in
  /// subscription order; a `Computed` is marked (and its listeners
  /// scheduled) before the ones it reaches.
  static void _markDescendants(ListNotifierSingleMixin from) {
    final dependents = from._dependents;
    if (dependents == null) return;
    for (var i = 0; i < dependents.length; i++) {
      final marked = dependents[i].markStale(false);
      if (marked != null) _markDescendants(marked);
    }
  }

  void _notifyUpdate() {
    if (_derived) {
      // A Computed telling its listeners: its version was already set and
      // its dependents already marked.
      _deliver();
      return;
    }
    _reactiveVersion++;
    Notifier._globalVersion++;
    if (_dependents != null) {
      _notifyWithDependents();
      return;
    }
    _deliver();
  }

  /// A change of app state with derived values subscribed: they are marked
  /// first (also inside a batch), then the listeners are told.
  void _notifyWithDependents() {
    // Counted as a notify, so derived values the marking scheduled run
    // after this notifier's own listeners, once.
    Notifier._depth++;
    try {
      final dependents = _dependents!;
      for (var i = 0; i < dependents.length; i++) {
        final marked = dependents[i].markStale(true);
        if (marked != null) _markDescendants(marked);
      }
      _deliver();
    } finally {
      if (--Notifier._depth == 0) Notifier._runReactionsIfIdle();
    }
  }

  @pragma('vm:prefer-inline')
  void _deliver() {
    if (Notifier._batchDepth > 0) {
      // Inside [Notifier.batch]: notify once, when the outermost batch ends.
      // Nothing to hold for a notifier nobody listens to.
      final list = _updaters;
      if (list == null || list.isEmpty) return;
      Notifier.instance._pending.add(this);
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
    Notifier._depth++;
    try {
      for (var i = 0; i < list.length; i++) {
        // A listener that throws is reported and the others still run (as
        // with ChangeNotifier). It used to stop the loop, so every later
        // listener (other Obx, workers, Computed) missed the change.
        final entry = list[i];
        if (entry == null) continue; // removed (a hole)
        try {
          entry.fn();
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
      if (--Notifier._depth == 0) Notifier._runReactionsIfIdle();
    }
  }

  bool get isDisposed => _holes < 0;

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
    final list = _updaters;
    return list == null ? 0 : list.length - _holes;
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _disposeListeners();
  }

  void _disposeListeners() {
    _updaters = null;
    _holes = -1;
    _dependents = null;
  }
}

/// One listener of a notifier. Its disposer holds it, so removal needs no
/// search: [index] is where it sits in the notifier's list.
final class _Listener {
  _Listener(this.fn, this.index);
  final GetStateUpdate fn;
  int index;
}

/// A derived value subscribed to a notifier with
/// [ListNotifierSingleMixin.addDependent] (a `Computed`).
///
/// A change does not run it: it is marked, and recomputes when read (or,
/// when something listens to it, once the change is fully applied).
/// [direct] is true when a source of app state changed (it must recompute)
/// and false when only another derived value it reads may have changed (it
/// checks that one first).
abstract interface class ReactiveDependent {
  /// Marks it; returns it when the mark is new (its own dependents must be
  /// marked maybe stale next), null when it already was (or cannot be)
  /// marked. The caller passes the mark on: one static function recursing
  /// with a direct call, about 30% faster on a deep chain than the
  /// dependent recursing into its notifier's method.
  ListNotifierSingleMixin? markStale(bool direct);
}

mixin ListNotifierGroupMixin on Listenable {
  /// Created on the first id (most controllers never use `GetBuilder` ids).
  HashMap<Object?, ListNotifierSingleMixin>? _updatersGroupIds;
  bool _groupsDisposed = false;

  HashMap<Object?, ListNotifierSingleMixin> get _groups =>
      _updatersGroupIds ??= HashMap<Object?, ListNotifierSingleMixin>();

  void _notifyGroupUpdate(Object id) {
    _updatersGroupIds?[id]?._notifyUpdate();
  }

  @protected
  void notifyGroupChildrens(Object id) {
    assert(_debugAssertNotDisposed());
    // Created on demand: reading an id nothing has registered yet used to
    // crash on a null check.
    Notifier.instance.read(_groups[id] ??= ListNotifierSingle());
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
      if (_groupsDisposed) {
        throw FlutterError('''A $runtimeType was used after being disposed.\n
'Once you have called dispose() on a $runtimeType, it can no longer be used.''');
      }
      return true;
    }());
    return true;
  }

  void removeListenerId(Object id, VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    _updatersGroupIds?[id]?.removeListener(listener);
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _updatersGroupIds?.forEach((key, value) => value.dispose());
    _updatersGroupIds = null;
    _groupsDisposed = true;
  }

  Disposer addListenerId(Object? key, GetStateUpdate listener) {
    assert(_debugAssertNotDisposed());
    return (_groups[key] ??= ListNotifierSingle()).addListener(listener);
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

  /// The observer being built / computed right now. Static so an untracked
  /// read (the common case) costs one field check (see [ListNotifierSingleMixin.reportRead]).
  static NotifyData? _notifyData;

  /// The [TrackedSources] of [_notifyData] (every observer here has one), so
  /// a tracked read goes straight to it: no [NotifyData] fields to load and
  /// no generic [ReadTracker] call. Null with [_notifyData], or for a
  /// [NotifyData] made without one.
  static TrackedSources? _tracker;

  // Static (with constant initializers) so the hot paths (a write, a
  // tracked read, a Computed's freshness check) read them with no lazy
  // initialization check and without going through [instance].
  static int _batchDepth = 0;
  final _pending = LinkedHashSet<ListNotifierSingleMixin>.identity();

  /// How many notifies are running (nested: a listener that writes an Rx).
  static int _depth = 0;

  static int _globalVersion = 0;

  /// Goes up on every Rx change. A derived value that last checked its
  /// sources at the current global version is known to be up to date
  /// without looking at them.
  int get globalVersion => _globalVersion;

  /// Same as [globalVersion], without going through [instance].
  static int get currentGlobalVersion => _globalVersion;

  final _reactions = LinkedHashSet<ScheduledReaction>.identity();

  /// Reactions that never schedule themselves twice before they run (see
  /// [scheduleUnique]): a plain list, swapped with [_queueSpare] per round,
  /// so the common case (a `Computed` with listeners) hashes and allocates
  /// nothing.
  var _queue = <ScheduledReaction>[];
  var _queueSpare = <ScheduledReaction>[];
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
    _reactionsPending = true;
    _runReactionsIfIdle();
  }

  /// Like [schedule], for a [reaction] that makes sure itself it is not
  /// scheduled again before it ran (a `Computed` schedules itself only when
  /// it goes from up to date to stale). Runs before the [schedule]d ones of
  /// the same round.
  void scheduleUnique(ScheduledReaction reaction) {
    _queue.add(reaction);
    _reactionsPending = true;
    _runReactionsIfIdle();
  }

  /// Something was scheduled and has not run yet. Static, so the end of
  /// every notify checks one field.
  static bool _reactionsPending = false;

  static void _runReactionsIfIdle() {
    if (_reactionsPending && _depth == 0 && _batchDepth == 0) {
      instance._runReactions();
    }
  }

  void _runReactions() {
    // Reactions scheduled while these run (an effect that writes) are run
    // by this loop in the next round, not nested.
    if (_runningReactions) return;
    _runningReactions = true;
    try {
      var rounds = 0;
      while (_queue.isNotEmpty || _reactions.isNotEmpty) {
        if (++rounds > maxReactionRounds) {
          _reactions.clear();
          _queue.clear();
          throw StateError(
              'Effects kept triggering each other for $maxReactionRounds '
              'rounds. An effect probably writes a value it reads.');
        }
        final queue = _queue;
        if (queue.isNotEmpty) {
          // Reactions scheduled meanwhile go to the other list.
          _queue = _queueSpare;
          try {
            for (var i = 0; i < queue.length; i++) {
              queue[i].runScheduled();
            }
          } finally {
            queue.clear();
            _queueSpare = queue;
          }
        }
        if (_reactions.isEmpty) continue;
        final list = _reactions.toList(growable: false);
        _reactions.clear();
        for (final reaction in list) {
          reaction.runScheduled();
        }
      }
    } finally {
      _reactionsPending = _queue.isNotEmpty || _reactions.isNotEmpty;
      _runningReactions = false;
    }
  }

  void add(VoidCallback listener) {
    _notifyData?.disposers.add(listener);
  }

  void read(ListNotifierSingleMixin updaters) {
    if (_notifyData != null) _readTracked(updaters);
  }

  /// A read while an observer runs ([_notifyData] is set).
  @pragma('vm:prefer-inline')
  static void _readTracked(ListNotifierSingleMixin updaters) {
    final tracker = _tracker;
    if (tracker != null) {
      tracker._readFast(updaters);
    } else {
      _readUntrackedData(updaters);
    }
  }

  /// A read under a [NotifyData] made without a [TrackedSources].
  static void _readUntrackedData(ListNotifierSingleMixin updaters) {
    final data = _notifyData!;
    final subscriptions = data.subscriptions;
    if (subscriptions != null) {
      subscriptions._read(updaters, data.updater);
      return;
    }
    final listener = data.updater;
    if (!updaters.containsListener(listener)) {
      updaters.addListener(listener);
      data.disposers.add(() => updaters.removeListener(listener));
    }
  }

  T append<T>(NotifyData data, T Function() builder) {
    final previous = _notifyData;
    final previousTracker = _tracker;
    _notifyData = data;
    final subscriptions = data.subscriptions;
    _tracker = subscriptions is TrackedSources ? subscriptions : null;
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
    } catch (_) {
      // A build that threw keeps its old subscriptions plus the ones it
      // made before the throw (an ObxError comes after _end: nothing to do).
      data.subscriptions?._abort();
      rethrow;
    } finally {
      _notifyData = previous;
      _tracker = previousTracker;
    }
  }

  /// Runs [fn] without subscribing the current observer to the Rx values it
  /// reads. See also `Rx.peek`.
  T untrack<T>(T Function() fn) {
    final previous = _notifyData;
    final previousTracker = _tracker;
    _notifyData = null;
    _tracker = null;
    try {
      return fn();
    } finally {
      _notifyData = previous;
      _tracker = previousTracker;
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

  /// The run that began with [_begin] threw before [_end].
  void _abort() {}
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

  /// The run that last read it. Only kept up to date where it is needed
  /// (see [TrackedSources._stamped]): a read in the same order as the last
  /// run does not write it.
  int run = 0;
  Disposer? disposer;
}

/// The sources a derived value (`Computed`), an `Effect` or an observer
/// widget (`Obx`, `GetX`) read on its last run, in read order, with the
/// version each had when it was read.
///
/// - [changed] tells, without running anything, whether any source moved on
///   since. A source that is itself a `Computed` brings itself up to date
///   first, so the answer is never based on a stale intermediate value.
/// - While [listen]ing, every source is subscribed; [unlisten] drops the
///   subscriptions but keeps the record, so a `Computed` nobody listens to
///   can still tell whether it needs to recompute.
/// - Reads usually repeat the last run exactly. Those are matched by
///   position: one identity check and a version store per read, no lookup
///   and no allocation.
class TrackedSources extends ReadTracker {
  List<_Source> _list = <_Source>[];

  /// Index by notifier (identity: `Rx` overrides `==`), built only once
  /// there are more than [_mapThreshold] sources. Below that a scan is
  /// cheaper than hashing, and an `Obx` reading a couple of values
  /// allocates no map at all.
  HashMap<ListNotifierSingleMixin, _Source>? _map;
  static const _mapThreshold = 8;

  int _run = 0;
  GetStateUpdate? _listener;

  /// Set instead of [_listener] by [listenAsDependent].
  ReactiveDependent? _dependent;

  /// While tracking: how many sources of [_list] were read again in the
  /// same order.
  int _cursor = 0;

  /// `_list[0 .. _stamped)` carry this run in [_Source.run]. Sources matched
  /// by position are stamped lazily, only when a read leaves the fast path.
  int _stamped = 0;
  bool _tracking = false;

  /// Set once a run reads something out of the last run's order; from
  /// there it collects into a new list.
  List<_Source>? _next;

  /// Reused by every [track] run (the disposers it collects are dropped).
  late final NotifyData _data = NotifyData(
    updater: _ignore,
    disposers: <Disposer>[],
    subscriptions: this,
    throwException: false,
  );

  int get length => _list.length;
  @override
  bool get isEmpty => _list.isEmpty;
  bool get isListening => _listener != null || _dependent != null;

  Disposer? _subscribe(ListNotifierSingleMixin notifier) {
    if (notifier.isDisposed) return null;
    final dependent = _dependent;
    return dependent != null
        ? notifier.addDependent(dependent)
        : notifier.addListener(_listener!);
  }

  /// Whether [notifier] was read on the last run.
  bool contains(ListNotifierSingleMixin notifier) => _lookup(notifier) != null;

  _Source? _lookup(ListNotifierSingleMixin notifier) {
    final map = _map;
    if (map != null) return map[notifier];
    for (final source in _list) {
      if (identical(source.notifier, notifier)) return source;
    }
    final next = _next;
    if (next != null) {
      // Sources that are new in this run are only in [_next] so far.
      for (var i = 0; i < next.length; i++) {
        final source = next[i];
        if (identical(source.notifier, notifier)) return source;
      }
    }
    return null;
  }

  void _indexIfLarge() {
    final next = _next;
    if (_map != null || _list.length + (next?.length ?? 0) <= _mapThreshold) {
      return;
    }
    final map = _map = HashMap<ListNotifierSingleMixin, _Source>.identity();
    for (final source in _list) {
      map[source.notifier] = source;
    }
    if (next != null) {
      for (final source in next) {
        map[source.notifier] = source;
      }
    }
  }

  /// Whether a source read on the last run changed since.
  @pragma('vm:prefer-inline')
  bool get changed {
    final list = _list;
    for (var i = 0; i < list.length; i++) {
      final source = list[i];
      final notifier = source.notifier;
      // A derived source brings itself up to date first (its getter).
      final version = notifier._derived
          ? notifier.reactiveVersion
          : notifier._reactiveVersion;
      if (version != source.version) return true;
    }
    return false;
  }

  /// Subscribes [listener] to every source, now and on later runs.
  void listen(GetStateUpdate listener) {
    if (isListening) return;
    _listener = listener;
    _subscribeAll();
  }

  /// Subscribes [dependent] to every source as a derived value (see
  /// [ReactiveDependent]), now and on later runs.
  void listenAsDependent(ReactiveDependent dependent) {
    if (isListening) return;
    _dependent = dependent;
    _subscribeAll();
  }

  void _subscribeAll() {
    for (final source in _list) {
      source.disposer = _subscribe(source.notifier);
    }
  }

  /// Drops the subscriptions, keeps the record of what was read.
  void unlisten() {
    _listener = null;
    _dependent = null;
    for (final source in _list) {
      source.disposer?.call();
      source.disposer = null;
    }
  }

  /// Runs [fn] and records what it reads. If [fn] throws, the sources read
  /// before the throw are added to the previous ones (so a change of any of
  /// them runs it again) and the error is rethrown.
  T track<T>(T Function() fn) {
    final previous = Notifier._notifyData;
    final previousTracker = Notifier._tracker;
    final data = _data;
    Notifier._notifyData = data;
    Notifier._tracker = this;
    if (data.disposers.isNotEmpty) data.disposers.clear();
    _begin();
    try {
      final result = fn();
      _end();
      return result;
    } catch (_) {
      _abort();
      rethrow;
    } finally {
      Notifier._notifyData = previous;
      Notifier._tracker = previousTracker;
    }
  }

  static void _ignore() {}

  @override
  void _begin() {
    _run++;
    _cursor = 0;
    _stamped = 0;
    _next = null;
    _tracking = true;
  }

  /// Stamps the sources matched by position so far with this run.
  void _stampMatched() {
    final list = _list;
    final run = _run;
    for (var i = _stamped; i < _cursor; i++) {
      list[i].run = run;
    }
    _stamped = _cursor;
  }

  /// A read in the same order as the last run (the usual case): one
  /// identity check and a version store, inlined into the read. Anything
  /// else goes to [_read].
  @pragma('vm:prefer-inline')
  void _readFast(ListNotifierSingleMixin notifier) {
    if (_next == null && _tracking) {
      final list = _list;
      final cursor = _cursor;
      if (cursor < list.length) {
        final source = list[cursor];
        if (identical(source.notifier, notifier)) {
          _cursor = cursor + 1;
          source.version = notifier._reactiveVersion;
          return;
        }
      }
    }
    _read(notifier, _ignore);
  }

  @override
  void _read(ListNotifierSingleMixin notifier, GetStateUpdate updater) {
    if (!_tracking) return;
    var next = _next;
    if (next == null) {
      // Same order as the last run so far.
      final list = _list;
      final cursor = _cursor;
      if (cursor < list.length) {
        final source = list[cursor];
        if (identical(source.notifier, notifier)) {
          _cursor = cursor + 1;
          source.version = notifier._reactiveVersion;
          return;
        }
      }
      _stampMatched();
      // A second read of a source already read in this run.
      final seen = _lookup(notifier);
      if (seen != null && seen.run == _run) return;
      next = _next = list.sublist(0, cursor);
    }
    var source = _lookup(notifier);
    if (source == null) {
      source = _Source(notifier);
      _map?[notifier] = source;
      if (isListening) source.disposer = _subscribe(notifier);
    } else if (source.run == _run) {
      return;
    }
    source.run = _run;
    next.add(source);
    _indexIfLarge();
    // A Computed source is already up to date: it validates before it
    // reports the read.
    source.version = notifier._reactiveVersion;
  }

  void _drop(_Source source) {
    source.disposer?.call();
    source.disposer = null;
    _map?.remove(source.notifier);
  }

  @override
  void _end() {
    _tracking = false;
    final next = _next;
    final list = _list;
    if (next == null) {
      // Same reads as last time, maybe fewer: drop the ones not read.
      if (_cursor == list.length) return;
      for (var i = _cursor; i < list.length; i++) {
        _drop(list[i]);
      }
      list.length = _cursor;
      return;
    }
    _next = null;
    for (final source in list) {
      if (source.run != _run) _drop(source);
    }
    _list = next;
  }

  @override
  void _abort() {
    _tracking = false;
    final next = _next;
    // Still in the last run's order: every old source is kept anyway.
    if (next == null) return;
    _next = null;
    for (final source in _list) {
      if (source.run != _run) next.add(source);
    }
    _list = next;
  }

  void dispose() {
    unlisten();
    _list.clear();
    _map = null;
  }
}
