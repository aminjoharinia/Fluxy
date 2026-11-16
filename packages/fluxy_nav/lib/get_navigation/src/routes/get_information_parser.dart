import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

class FluxyInformationParser extends RouteInformationParser<RouteDecoder> {
  factory FluxyInformationParser.createInformationParser({
    String initialRoute = '/',
    bool redirectRootToInitialRoute = false,
  }) {
    return FluxyInformationParser(
      initialRoute: initialRoute,
      redirectRootToInitialRoute: redirectRootToInitialRoute,
    );
  }

  /// Where the app starts when it is opened at `/` (or with no address).
  final String initialRoute;

  /// When true, `/` always goes to [initialRoute]. When false (the default),
  /// only when `/` is not a registered page.
  final bool redirectRootToInitialRoute;

  FluxyInformationParser({
    required this.initialRoute,
    this.redirectRootToInitialRoute = false,
  }) {
    Fluxy.log('GetInformationParser is created !');
  }
  @override
  SynchronousFuture<RouteDecoder> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    final uri = routeInformation.uri;
    var location = uri.toString();
    if (location == '/') {
      // Go to initialRoute when asked to, or when '/' is not a page.
      if (redirectRootToInitialRoute ||
          !(Fluxy.rootController.rootDelegate)
          .registeredRoutes
          .any((element) => element.name == '/')) {
        location = initialRoute;
      }
    } else if (location.isEmpty) {
      location = initialRoute;
    }

    Fluxy.log('GetInformationParser: route location: $location');

    return SynchronousFuture(RouteDecoder.fromRoute(location));
  }

  @override
  RouteInformation restoreRouteInformation(RouteDecoder configuration) {
    return RouteInformation(
      uri: Uri.tryParse(configuration.pageSettings?.name ?? ''),
      state: null,
    );
  }
}
