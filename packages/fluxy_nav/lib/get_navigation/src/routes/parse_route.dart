import 'package:flutter/foundation.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

@immutable
class RouteDecoder {
  const RouteDecoder(this.currentTreeBranch, this.pageSettings);
  final List<FluxyPage> currentTreeBranch;
  final PageSettings? pageSettings;

  factory RouteDecoder.fromRoute(String location) {
    var uri = Uri.parse(location);
    final args = PageSettings(uri);
    final decoder = (Fluxy.rootController.rootDelegate).matchRoute(
      location,
      arguments: args,
    );
    decoder.route = decoder.route?.copyWith(
      completer: null,
      arguments: args,
      parameters: args.params,
    );
    return decoder;
  }

  FluxyPage? get route =>
      currentTreeBranch.isEmpty ? null : currentTreeBranch.last;

  FluxyPage routeOrUnknown(FluxyPage onUnknow) =>
      currentTreeBranch.isEmpty ? onUnknow : currentTreeBranch.last;

  set route(FluxyPage? getPage) {
    if (getPage == null) return;
    if (currentTreeBranch.isEmpty) {
      currentTreeBranch.add(getPage);
    } else {
      currentTreeBranch[currentTreeBranch.length - 1] = getPage;
    }
  }

  List<FluxyPage>? get currentChildren => route?.children;

  Map<String, String> get parameters => pageSettings?.params ?? {};

  dynamic get args {
    return pageSettings?.arguments;
  }

  T? arguments<T>() {
    final args = pageSettings?.arguments;
    if (args is T) {
      return pageSettings?.arguments as T;
    } else {
      return null;
    }
  }

  // void replaceArguments(Object? arguments) {
  //   final newRoute = route;
  //   if (newRoute != null) {
  //     final index = currentTreeBranch.indexOf(newRoute);
  //     currentTreeBranch[index] = newRoute.copyWith(arguments: arguments);
  //   }
  // }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RouteDecoder &&
        listEquals(other.currentTreeBranch, currentTreeBranch) &&
        other.pageSettings == pageSettings;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(currentTreeBranch), pageSettings);

  @override
  String toString() =>
      'RouteDecoder(currentTreeBranch: $currentTreeBranch, pageSettings: $pageSettings)';
}
