import 'dart:async';

import 'package:flutter/foundation.dart';

import 'route_match.dart';

/// Decides where a navigation to an address goes.
///
/// Return null to let it through, another address to go there instead, or
/// [NavRequest.stop] to cancel it (the stack doesn't change and the
/// navigation's future completes with null). May be asynchronous: later
/// navigations wait for it, in call order.
typedef FluxyRedirect = FutureOr<String?> Function(NavRequest request);

/// Called with the match of a page's entry when it goes on the stack
/// ([FluxyPage.onEnter]) or leaves it ([FluxyPage.onLeave]).
typedef FluxyPageCallback = void Function(RouteMatch match);

/// A navigation to an address, as a [FluxyRedirect] sees it.
@immutable
class NavRequest {
  const NavRequest(this.match, {this.arguments, this.from});

  /// Return this from a [FluxyRedirect] to cancel the navigation.
  ///
  /// It's not an address, so it can't be returned by mistake; an empty
  /// address is reported as an error (and cancels too).
  static const String stop = '\u0000fluxy:stop';

  /// The address matched against the route table. [isUnknown] when no page
  /// is registered for it.
  final RouteMatch match;

  /// The arguments given to the navigation.
  final Object? arguments;

  /// The location shown before this navigation; null for the first address
  /// the app opens.
  final String? from;

  /// Whether this is the first address (the one the app was opened at).
  bool get isInitial => from == null;

  bool get isUnknown => match.isUnknown;

  Uri get uri => match.uri;

  /// The path, without the query (`/item/42`).
  String get path => match.path;

  /// The path and query (`/item/42?tab=2`).
  String get location => match.location;

  /// Path and query parameters (path wins).
  Map<String, String> get parameters => match.parameters;

  @override
  String toString() => 'NavRequest($location${isInitial ? ', initial' : ''})';
}
