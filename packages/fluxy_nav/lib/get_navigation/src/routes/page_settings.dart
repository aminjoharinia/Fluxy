import 'package:flutter/widgets.dart';

import 'package:fluxy_nav/fluxy_nav.dart';

extension PageArgExt on BuildContext {
  RouteSettings? get settings {
    return ModalRoute.of(this)!.settings;
  }

  PageSettings? get pageSettings {
    final args = ModalRoute.of(this)?.settings.arguments;
    if (args is PageSettings) {
      return args;
    }
    return null;
  }

  dynamic get arguments {
    final args = settings?.arguments;
    if (args is PageSettings) {
      return args.arguments;
    } else {
      return args;
    }
  }

  Map<String, String> get params {
    final args = settings?.arguments;
    if (args is PageSettings) {
      return args.params;
    } else {
      return {};
    }
  }

  Router get router {
    return Router.of(this);
  }

  String get location {
    final parser = router.routeInformationParser;
    final config = delegate.currentConfiguration;
    return parser?.restoreRouteInformation(config)?.uri.toString() ?? '/';
  }

  FluxyDelegate get delegate {
    return router.routerDelegate as FluxyDelegate;
  }
}

class PageSettings extends RouteSettings {
  PageSettings(
    this.uri, [
    Object? arguments,
    Map<String, String>? params,
  ])  : params = Map.unmodifiable(params ?? uri.queryParameters),
        super(arguments: arguments);

  @override
  String get name => '$uri';

  final Uri uri;

  /// Path and query parameters of the matched address (path wins).
  final Map<String, String> params;

  String get path => uri.path;

  List<String> get paths => uri.pathSegments;

  Map<String, String> get query => uri.queryParameters;

  Map<String, List<String>> get queries => uri.queryParametersAll;

  @override
  String toString() => name;

  PageSettings copy({
    Uri? uri,
    Object? arguments,
  }) {
    return PageSettings(
      uri ?? this.uri,
      arguments ?? this.arguments,
      uri == null ? params : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PageSettings &&
        other.uri == uri &&
        other.arguments == arguments;
  }

  @override
  int get hashCode => uri.hashCode ^ arguments.hashCode;
}
