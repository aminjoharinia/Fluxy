import 'package:flutter/widgets.dart';

import 'default_route.dart';

enum Transition {
  fade,
  fadeIn,
  rightToLeft,
  leftToRight,
  upToDown,
  downToUp,
  rightToLeftWithFade,
  leftToRightWithFade,
  zoom,
  topLevel,
  noTransition,
  cupertino,
  cupertinoDialog,
  size,
  circularReveal,
  native,
}

typedef FluxyPageBuilder = Widget Function();
typedef FluxyRouteAwarePageBuilder<T> = Widget Function([
  FluxyPageRoute<T>? route,
]);
