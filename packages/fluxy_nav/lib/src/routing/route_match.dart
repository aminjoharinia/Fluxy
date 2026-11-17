import 'package:flutter/foundation.dart';

import 'fluxy_page.dart';
import 'nav_request.dart';

/// The result of matching an address against a [RouteTable].
///
/// Immutable: [branch], [parameters] and [pathParameters] can't be changed.
@immutable
class RouteMatch {
  RouteMatch({
    required this.uri,
    required List<FluxyPage> branch,
    required List<String> patterns,
    required Map<String, String> pathParameters,
    List<FluxyRedirect> redirects = const [],
  }) : branch = List.unmodifiable(branch),
       redirects = List.unmodifiable(redirects),
       patterns = List.unmodifiable(patterns),
       pathParameters = Map.unmodifiable(pathParameters),
       parameters = Map.unmodifiable({
         ...uri.queryParameters,
         ...pathParameters,
       });

  /// A match for an address no page is registered for.
  RouteMatch.unknown(this.uri)
    : branch = const [],
      redirects = const [],
      patterns = const [],
      pathParameters = const {},
      parameters = Map.unmodifiable(uri.queryParameters);

  /// A match for a page that isn't in a route table, like the ones
  /// `Fluxy.to(() => Page())` opens.
  RouteMatch.direct(FluxyPage page, this.uri)
    : branch = List.unmodifiable([page]),
      redirects = List.unmodifiable([?page.redirect]),
      patterns = List.unmodifiable([page.name]),
      pathParameters = const {},
      parameters = Map.unmodifiable(uri.queryParameters);

  /// The address, path and query only (`/item/42?tab=2`).
  final Uri uri;

  /// The pages from the outermost registered parent to the matched page.
  /// Each page's `name` is the concrete path it matched (`/item/42`) and its
  /// key is a `ValueKey` of that path.
  final List<FluxyPage> branch;

  /// The registered names of [branch] (`/item/:id`), same order.
  final List<String> patterns;

  /// The redirects of the matched page and the pages it's declared under,
  /// outermost first, in the order they run.
  final List<FluxyRedirect> redirects;

  /// Values of `:name` and `*name` segments.
  final Map<String, String> pathParameters;

  /// Query parameters plus [pathParameters]; a path parameter wins over a
  /// query parameter with the same name.
  final Map<String, String> parameters;

  /// The matched page, or null for an unknown address.
  FluxyPage? get page => branch.isEmpty ? null : branch.last;

  bool get isUnknown => branch.isEmpty;

  String get path => uri.path;

  /// The address as a string, the way it's shown in the URL.
  String get location => uri.toString();

  @override
  String toString() => 'RouteMatch($location, ${patterns.join(' > ')})';
}
