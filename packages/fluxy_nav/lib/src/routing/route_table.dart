import 'package:flutter/foundation.dart';

import 'package:fluxy_state/fluxy_state.dart';

import '../../get_navigation/src/routes/get_route.dart';
import '../../get_navigation/src/routes/route_middleware.dart';
import 'route_match.dart';

/// The registered pages, matched by path segment.
///
/// Built once from the app's pages: children are flattened to their full
/// path and get their parents' bindings and middlewares. Navigation never
/// changes it; `Fluxy.to(() => Page())` pages aren't added to it.
///
/// Segments are matched by priority, whatever the order the pages were
/// registered in: a static segment (`/settings`) beats a parameter (`/:id`),
/// which beats a wildcard (`/*rest`). Patterns:
///
/// * `/user/:id` - one segment, as `id`
/// * `/user/:id?` - with or without that segment
/// * `/files/*path` - one or more remaining segments, joined with `/`, as
///   `path` (`*` alone stores nothing)
///
/// A trailing slash doesn't matter, case does. When two pages have the
/// same pattern, the first one wins.
class RouteTable {
  RouteTable(Iterable<FluxyPage> pages) {
    for (final page in pages) {
      _flatten(page, null, const [], const [], const []);
    }
    routes = List.unmodifiable(_routes);
  }

  final _root = _Node();
  final _routes = <FluxyPage>[];

  /// Every registered page, children flattened to their full paths.
  late final List<FluxyPage> routes;

  /// Whether a page is registered with exactly this [pattern].
  bool contains(String pattern) =>
      routes.any((p) => p.name == pattern || p.name == _trim(pattern));

  /// The page registered with this [pattern], if any.
  FluxyPage? operator [](String pattern) {
    final name = _trim(pattern);
    for (final p in routes) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Matches [location] (a path, optionally with a query; a full URL's
  /// scheme and host are ignored).
  RouteMatch match(String location) {
    final parsed = Uri.parse(location);
    final uri = Uri(
      path: parsed.path.isEmpty ? '/' : parsed.path,
      query: parsed.hasQuery && parsed.query.isNotEmpty ? parsed.query : null,
    );
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final path = <_Node>[];
    if (!_walk(_root, segments, 0, path)) return RouteMatch.unknown(uri);
    final params = _params(path.last.pattern!, segments);

    final branch = <FluxyPage>[];
    final patterns = <String>[];
    for (final node in path) {
      final page = node.page;
      if (page == null) continue;
      final concrete = node.depth == 0
          ? '/'
          : '/${segments.take(node.depth).join('/')}';
      final full = node.wildcard ? '/${segments.join('/')}' : concrete;
      patterns.add(page.name);
      branch.add(
        page.copyWith(
          name: full,
          key: ValueKey(full),
          parameters: {...?page.parameters, ...uri.queryParameters, ...params},
        ),
      );
    }
    return RouteMatch(
      uri: uri,
      branch: branch,
      patterns: patterns,
      pathParameters: params,
    );
  }

  /// The children declared on the page registered as [pattern], as written
  /// (not flattened).
  List<FluxyPage> childrenOf(String pattern) => this[pattern]?.children ?? [];

  bool _walk(_Node node, List<String> segments, int i, List<_Node> path) {
    path.add(node);
    if (node.wildcard || i == segments.length) {
      if (node.page != null) return true;
      path.removeLast();
      return false;
    }
    final static = node.statics[segments[i]];
    if (static != null && _walk(static, segments, i + 1, path)) return true;
    final param = node.param;
    if (param != null && _walk(param, segments, i + 1, path)) return true;
    final wild = node.wildcardChild;
    if (wild != null && _walk(wild, segments, i + 1, path)) return true;
    path.removeLast();
    return false;
  }

  static Map<String, String> _params(
    List<String> pattern,
    List<String> segments,
  ) {
    final params = <String, String>{};
    for (var k = 0; k < pattern.length && k < segments.length; k++) {
      final p = pattern[k];
      if (p.startsWith(':') && p.length > 1) {
        params[p.substring(1)] = segments[k];
      } else if (p.startsWith('*')) {
        if (p.length > 1) params[p.substring(1)] = segments.skip(k).join('/');
        break;
      }
    }
    return params;
  }

  void _flatten(
    FluxyPage page,
    String? parentPath,
    List<FluxyMiddleware> middlewares,
    List<BindingsInterface> bindings,
    List<Bind> binds,
  ) {
    final name = parentPath == null || !page.inheritParentPath
        ? page.name
        : _trim('$parentPath${page.name}'.replaceAll('//', '/'));
    final ownBindings = [
      if (page.binding != null) page.binding!,
      ...page.bindings,
    ];
    final resolved = parentPath == null
        ? page
        : page.copyWith(
            name: name,
            key: ValueKey(name),
            middlewares: [...middlewares, ...page.middlewares],
            bindings: [...page.bindings, ...bindings],
            binds: [...binds, ...page.binds],
          );
    _add(resolved);
    for (final child in page.children) {
      _flatten(child, name, resolved.middlewares, [
        ...ownBindings,
        ...bindings,
      ], resolved.binds);
    }
  }

  void _add(FluxyPage page) {
    _routes.add(page);
    final segments = _trim(page.name).split('/').where((s) => s.isNotEmpty);
    var variants = [<String>[]];
    for (final s in segments) {
      if (s.startsWith(':') && s.endsWith('?')) {
        final required = s.substring(0, s.length - 1);
        variants = [
          for (final v in variants) ...[
            v,
            [...v, required],
          ],
        ];
      } else {
        for (final v in variants) {
          v.add(s);
        }
      }
    }
    for (final v in variants) {
      _insert(v, page);
    }
  }

  void _insert(List<String> segments, FluxyPage page) {
    var node = _root;
    for (final s in segments) {
      if (node.wildcard) break; // nothing can follow a wildcard
      if (s.startsWith(':') && s.length > 1) {
        // Patterns naming this position differently share the node; the
        // names come from the matched page's own pattern.
        node = node.param ??= _Node(depth: node.depth + 1);
      } else if (s.startsWith('*')) {
        node = node.wildcardChild ??= _Node(
          depth: node.depth + 1,
          wildcard: true,
        );
      } else {
        node = node.statics.putIfAbsent(s, () => _Node(depth: node.depth + 1));
      }
    }
    if (node.page == null) {
      node.page = page;
      node.pattern = segments;
    }
  }

  static String _trim(String path) => path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}

class _Node {
  _Node({this.depth = 0, this.wildcard = false});

  final int depth;
  final bool wildcard;
  final statics = <String, _Node>{};
  _Node? param;
  _Node? wildcardChild;
  FluxyPage? page;
  List<String>? pattern;
}
