import 'dart:async';

import 'package:flutter/foundation.dart';

import '../router/navigation_interface.dart';
import 'fluxy_page.dart';
import 'page_settings.dart';
import 'route_match.dart';

/// One page in the navigation history.
///
/// Immutable. The [page] is what the navigator shows: the matched page with
/// this entry's key, its [PageSettings] as `arguments` and the completer
/// behind [result].
@immutable
class NavEntry {
  const NavEntry._(
    this.match,
    this.page,
    this.arguments,
    this._accepts,
    this.marksRootNavigator,
  );

  /// Creates an entry whose [result] is a `Future<T?>`.
  ///
  /// [page] defaults to the matched page. [key] defaults to a `ValueKey` of
  /// the location.
  static NavEntry create<T>({
    required RouteMatch match,
    FluxyPage? page,
    Object? arguments,
    LocalKey? key,
  }) {
    final source = page ?? match.page!;
    final settings = PageSettings(match.uri, arguments, match.parameters);
    final configured = source.copyWith(
      key: key ?? ValueKey(match.location),
      arguments: settings,
      parameters: {...?source.parameters, ...match.parameters},
      completer: Completer<T?>(),
    );
    return NavEntry._(
      match,
      configured,
      arguments,
      (r) => r is T?,
      match.branch.any((p) => p.participatesInRootNavigator != null),
    );
  }

  final RouteMatch match;
  final FluxyPage page;
  final Object? arguments;
  final bool Function(Object?) _accepts;

  /// Whether a page of [branch] sets
  /// [FluxyPage.participatesInRootNavigator].
  final bool marksRootNavigator;

  LocalKey get key => page.key!;

  /// The concrete path of the page (`/item/42`), without the query.
  String get name => page.name;

  /// The address, with the query (`/item/42?tab=2`).
  String get location => match.location;

  PageSettings get settings => page.arguments as PageSettings;

  /// The pages from the outermost registered parent to this one, with
  /// this entry's page last.
  List<FluxyPage> get branch => match.branch.isEmpty
      ? [page]
      : [...match.branch.take(match.branch.length - 1), page];

  Completer<dynamic> get _completer => page.completer!;

  /// Shared by an entry and its [withKey] copies: the same history item.
  Object get token => _completer;

  /// Completes when the entry leaves the stack.
  Future<Object?> get result => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  /// Completes [result] once. A value of the wrong type completes it with
  /// null.
  void complete([Object? value]) {
    if (_completer.isCompleted) return;
    _completer.complete(_accepts(value) ? value : null);
  }

  /// The same entry (same result future) under another key.
  NavEntry withKey(LocalKey key) => NavEntry._(
    match,
    page.copyWith(key: key),
    arguments,
    _accepts,
    marksRootNavigator,
  );

  @override
  String toString() => 'NavEntry($location)';
}

/// The navigation history: an immutable list of [NavEntry], bottom first.
///
/// Every change returns a new stack; nothing here completes entries or
/// talks to widgets. The delegate compares the old and new stacks and
/// completes the entries that left.
@immutable
class NavStack {
  NavStack([Iterable<NavEntry> entries = const []])
    : entries = List.unmodifiable(entries);

  final List<NavEntry> entries;

  bool get isEmpty => entries.isEmpty;
  int get length => entries.length;
  NavEntry? get top => entries.isEmpty ? null : entries.last;

  /// The entry under [top], if any.
  NavEntry? get below =>
      entries.length < 2 ? null : entries[entries.length - 2];

  /// Whether a page can be popped; the last page always stays.
  bool get canPop => entries.length > 1;

  NavStack push(NavEntry entry) => NavStack([...entries, entry]);

  /// Removes the top entry, unless it is the last one.
  NavStack pop() => canPop ? NavStack(entries.take(entries.length - 1)) : this;

  /// Replaces the top entry, following the duplicate rules of [add] for
  /// the rest of the stack.
  NavStack replaceTopWith(
    NavEntry entry, {
    PreventDuplicateHandlingMode mode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) =>
      NavStack(entries.take(isEmpty ? 0 : entries.length - 1))
          .add(entry, mode: mode);

  /// Replaces the top entry (pushes when empty). It doesn't check for
  /// duplicates; see [replaceTopWith].
  NavStack replaceTop(NavEntry entry) => isEmpty
      ? NavStack([entry])
      : NavStack([...entries.take(entries.length - 1), entry]);

  /// Pops while there is more than one entry and [keep] is false for the
  /// top one.
  NavStack popUntil(bool Function(NavEntry entry) keep) {
    var end = entries.length;
    while (end > 1 && !keep(entries[end - 1])) {
      end--;
    }
    return end == entries.length ? this : NavStack(entries.take(end));
  }

  /// Like [popUntil], but may remove every entry.
  NavStack removeUntil(bool Function(NavEntry entry) keep) {
    var end = entries.length;
    while (end > 0 && !keep(entries[end - 1])) {
      end--;
    }
    return end == entries.length ? this : NavStack(entries.take(end));
  }

  NavStack remove(NavEntry entry) =>
      NavStack(entries.where((e) => !identical(e, entry)));

  NavStack replace(NavEntry old, NavEntry entry) =>
      NavStack([for (final e in entries) identical(e, old) ? entry : e]);

  /// The last entry at [location], if any.
  NavEntry? lastAt(String location) {
    for (var i = entries.length - 1; i >= 0; i--) {
      if (entries[i].location == location) return entries[i];
    }
    return null;
  }

  /// Adds [entry] following the duplicate rules.
  ///
  /// An entry is a duplicate when one with the same location is already on
  /// the stack. With [preventDuplicates] false it's added anyway under a
  /// key of its own. Otherwise, per [mode]:
  ///
  /// * `reorderRoutes` - the old entry leaves, the new one goes on top
  ///   under the same key (the navigator keeps the page)
  /// * `recreate` - the same, under a new key (the page is built again)
  /// * `popUntilOriginalRoute` - the entries above the old one leave;
  ///   the new one isn't added
  /// * `doNothing` - nothing changes; the new one isn't added
  NavStack add(
    NavEntry entry, {
    bool preventDuplicates = true,
    PreventDuplicateHandlingMode mode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) {
    final existing = lastAt(entry.location);
    if (existing == null) return push(entry);
    if (!preventDuplicates) return push(entry.withKey(UniqueKey()));
    switch (mode) {
      case PreventDuplicateHandlingMode.doNothing:
        return this;
      case PreventDuplicateHandlingMode.reorderRoutes:
        return remove(existing).push(entry.withKey(existing.key));
      case PreventDuplicateHandlingMode.recreate:
        return remove(existing).push(entry.withKey(UniqueKey()));
      case PreventDuplicateHandlingMode.popUntilOriginalRoute:
        return popUntil((e) => identical(e, existing));
    }
  }

  @override
  String toString() => 'NavStack(${entries.map((e) => e.location).join(', ')})';
}
