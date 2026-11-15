import 'dart:async';

import '../../../get_state_manager/src/rx_flutter/rx_notifier.dart';
import '../../../get_state_manager/src/simple/list_notifier.dart';
import '../rx_types/rx_types.dart';
import '../rx_workers/rx_workers.dart';

// Immutable edits: the way to change Rx state.
//
// An Rx notifies when it gets a *new value* (`value = ...`, `map[key] = ...`,
// `list[i] = ...`, `add` / `remove` ...), never because something inside an
// old value was changed behind its back. So state is not edited in place and
// then "announced": the changed entry is rebuilt as a new map / list and
// written back through the Rx, which is what notifies. Only the edited path
// is copied; everything else is shared.
//
// In debug builds, assigning an Rx the same Map / List / Set object it already
// holds logs a warning: that is the usual sign of an in-place edit that will
// not notify.

/// A copy of [source] with [changes] merged in (keys always Strings, as in
/// JSON).
Map<String, dynamic> mapWith(Object? source, Map<String, dynamic> changes) =>
    <String, dynamic>{
      if (source is Map)
        for (final e in source.entries) '${e.key}': e.value,
      ...changes,
    };

/// A copy of [source] (a List, or nothing) with [value] appended.
List<dynamic> listWith(Object? source, Object? value) =>
    [if (source is List) ...source, value];

/// A copy of [source] without the item at [index].
List<dynamic> listWithout(Object? source, int index) => [
      if (source is List)
        for (var i = 0; i < source.length; i++)
          if (i != index) source[i],
    ];

/// A copy of [source] with the item at [index] replaced by [value].
List<dynamic> listReplaced(Object? source, int index, Object? value) => [
      if (source is List)
        for (var i = 0; i < source.length; i++) i == index ? value : source[i],
    ];

/// A copy of [root] with the value at [path] replaced by [update] (given the
/// old value). [path] steps are String keys (maps) and int positions (lists).
/// Only the maps / lists on the way down are copied.
Object? updatedIn(
    Object? root, List<Object> path, Object? Function(Object? old) update) {
  if (path.isEmpty) return update(root);
  final step = path.first;
  final rest = path.sublist(1);
  if (root is List && step is int) {
    final copy = List<dynamic>.of(root);
    copy[step] = updatedIn(root[step], rest, update);
    return copy;
  }
  final copy = mapWith(root, const {});
  copy['$step'] = updatedIn(root is Map ? root[step] : null, rest, update);
  return copy;
}

extension RxListItemEdit<E> on RxList<E> {
  /// Replaces item [index] (a map) by a copy with [changes] merged in.
  void patch(int index, Map<String, dynamic> changes) {
    this[index] = mapWith(peek[index], changes) as E;
  }

  /// Puts [item] where [old] (the very same object) is, or appends it when
  /// [old] is not here.
  void replaceItem(Object? old, E item) {
    final i = peek.indexWhere((e) => identical(e, old));
    if (i >= 0) {
      this[i] = item;
    } else {
      add(item);
    }
  }

  /// Moves an item, as `ReorderableListView` reports it ([newIndex] counted
  /// before the removal). Notifies once.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = peek;
    list.insert(newIndex, list.removeAt(oldIndex));
    // ignore: invalid_use_of_protected_member
    refresh();
  }
}

extension RxMapEntryEdit<V> on RxMap<String, V> {
  /// Replaces entry [key] (a map) by a copy with [changes] merged in.
  void patch(String key, Map<String, dynamic> changes) {
    this[key] = mapWith(peek[key], changes) as V;
  }

  /// Appends [value] to the list under [key] (created when missing), as a
  /// new list.
  void addEntry(String key, [Object? value = '']) {
    this[key] = listWith(peek[key], value) as V;
  }

  /// Removes item [index] of the list under [key], as a new list.
  void removeEntryAt(String key, int index) {
    this[key] = listWithout(peek[key], index) as V;
  }

  /// Removes [value] from the list under [key], as a new list.
  void removeEntry(String key, Object? value) {
    final list = peek[key];
    this[key] = [if (list is List) ...list.where((e) => e != value)] as V;
  }
}

/// Documents (big JSON trees): change one path, share the rest.
extension RxDocumentEdit on RxMap<String, dynamic> {
  /// Writes [value] at [path] (e.g. `["Places", 0, "Sections", 2, "Name"]`)
  /// as a new value.
  void setIn(List<Object> path, Object? value) => updateIn(path, (_) => value);

  /// Replaces the value at [path] by `update(old)` as a new value.
  void updateIn(List<Object> path, Object? Function(Object? old) update) {
    final top = path.first as String;
    this[top] = updatedIn(peek[top], path.sublist(1), update);
  }

  /// Merges [changes] into the map at [path] as a new value.
  void patchIn(List<Object> path, Map<String, dynamic> changes) =>
      updateIn(path, (old) => mapWith(old, changes));

  /// Runs list operations (add / insert / removeAt / removeWhere / sort ...)
  /// on a copy of the list at [path] and stores that copy. Items are shared:
  /// change an item with [patchIn].
  void editListIn(List<Object> path, void Function(List<dynamic> list) edit) =>
      updateIn(path, (old) {
        final copy = [if (old is List) ...old];
        edit(copy);
        return copy;
      });
}

/// Calls [callback] with the new value every time [rx] changes, until the
/// returned worker is disposed.
///
/// Like `ever`, the value is taken when it changes and the callback runs in a
/// microtask (never inside the setter, or a build that set it), but it
/// listens directly instead of through the Rx's stream.
Worker watchRx<T>(GetListenable<T> rx, void Function(T value) callback) {
  var disposed = false;
  final remove = rx.addListener(() {
    final value = rx.peek;
    scheduleMicrotask(() {
      if (!disposed) callback(value);
    });
  });
  return Worker(() async {
    disposed = true;
    remove();
  }, '[watchRx]');
}

/// One part of other Rx values, notifying only when that part is a new
/// object.
///
/// An `Obx` rebuilds whenever any Rx it read gets a new value. A screen that
/// shows one item of a big value (one section of the open place) reads it
/// through a slice instead: [select] runs again when a source changes, and
/// readers are told only when it returns a new object (`identical`). Edits
/// elsewhere share the item, so they do not rebuild the screen.
///
/// Listens synchronously, so it is current as soon as a source's setter
/// returns. Make one per screen (`initState`) and [dispose] it with the
/// screen.
class RxSlice<T> {
  RxSlice(List<GetListenable<Object?>> sources, T Function() select)
      : _select = select,
        _rx = Rx<T>(select()) {
    for (final source in sources) {
      _stop.add(source.addListener(update));
    }
  }

  final T Function() _select;
  final Rx<T> _rx;
  final List<void Function()> _stop = [];

  /// The selected part; reading it inside an `Obx` subscribes to this slice
  /// only.
  T get value => _rx.value;

  /// The selected part, without subscribing.
  T get peek => _rx.peek;

  /// Calls [listener] each time the slice gets a new value; returns the call
  /// that stops it.
  void Function() addListener(void Function() listener) =>
      _rx.addListener(listener);

  /// Selects again, and notifies when the result is a new object. Sources
  /// call it; call it too after a change it cannot see (a local edit).
  void update() {
    final next = Notifier.instance.untrack(_select);
    final old = _rx.peek;
    if (identical(old, next) || (old is! Map && old is! List && old == next)) {
      return;
    }
    _rx.value = next;
  }

  /// Stops listening to the sources.
  void dispose() {
    for (final stop in _stop) {
      stop();
    }
    _stop.clear();
  }
}
