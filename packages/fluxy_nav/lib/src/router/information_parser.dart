import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';

/// Turns the platform's route information (the URL on the web, the
/// initial route elsewhere) into the address the [FluxyDelegate] opens.
class FluxyInformationParser extends RouteInformationParser<Uri> {
  factory FluxyInformationParser.createInformationParser({
    String initialRoute = '/',
    bool redirectRootToInitialRoute = false,
  }) {
    return FluxyInformationParser(
      initialRoute: initialRoute,
      redirectRootToInitialRoute: redirectRootToInitialRoute,
    );
  }

  /// Where the app starts when it is opened with no address, and at `/`
  /// when [redirectRootToInitialRoute] is true.
  final String initialRoute;

  /// When true, `/` goes to [initialRoute]. `FluxyApp` sets it when it was
  /// given an `initialRoute`, or when `/` is not a page.
  ///
  /// For anything that depends on the app's state (signed in or not),
  /// use `FluxyApp(redirect: ...)`, which also sees the first address.
  final bool redirectRootToInitialRoute;

  FluxyInformationParser({
    this.initialRoute = '/',
    this.redirectRootToInitialRoute = false,
  }) {
    Fluxy.log('FluxyInformationParser is created !');
  }

  @override
  SynchronousFuture<Uri> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    final uri = routeInformation.uri;
    var location = uri.toString();
    if (location.isEmpty ||
        (location == '/' && redirectRootToInitialRoute)) {
      location = initialRoute;
    }
    Fluxy.log('FluxyInformationParser: route location: $location');
    return SynchronousFuture(Uri.parse(location));
  }

  @override
  RouteInformation restoreRouteInformation(Uri configuration) {
    return RouteInformation(uri: configuration);
  }
}
