import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

class GetInformationParser extends RouteInformationParser<RouteDecoder> {
  factory GetInformationParser.createInformationParser({
    String initialRoute = '/',
    bool redirectRootToInitialRoute = false,
  }) {
    return GetInformationParser(
      initialRoute: initialRoute,
      redirectRootToInitialRoute: redirectRootToInitialRoute,
    );
  }

  /// Where the app starts when it is opened at `/` (or with no address).
  final String initialRoute;

  /// When true, `/` always goes to [initialRoute]. When false (the default),
  /// only when `/` is not a registered page.
  final bool redirectRootToInitialRoute;

  GetInformationParser({
    required this.initialRoute,
    this.redirectRootToInitialRoute = false,
  }) {
    Get.log('GetInformationParser is created !');
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
          !(Get.rootController.rootDelegate)
          .registeredRoutes
          .any((element) => element.name == '/')) {
        location = initialRoute;
      }
    } else if (location.isEmpty) {
      location = initialRoute;
    }

    Get.log('GetInformationParser: route location: $location');

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
