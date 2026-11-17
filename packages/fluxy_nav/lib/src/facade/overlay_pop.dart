import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

/// Pops the top route of the navigator for [id] when it's a popup
/// (dialog, sheet, menu). Never pops a page. Returns whether it popped.
bool popTopOverlay<T>(String? id, [T? result]) {
  final nav = Fluxy.searchDelegate(id).navigatorKey.currentState;
  if (nav == null) return false;
  Route<dynamic>? top;
  nav.popUntil((route) {
    top = route;
    return true;
  });
  if (top is! PopupRoute) return false;
  nav.pop(result);
  return true;
}
