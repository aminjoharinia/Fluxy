// Version-specific calls (v1.2.0). The v1.0.0 build swaps this file for
// adapter_v1_0.dart.txt (renamed to adapter.dart).
import 'package:fluxy/fluxy.dart';

/// Matches [location] against the root delegate's pages; true when found.
bool match(String location) =>
    !Fluxy.rootController.rootDelegate.routeTable.match(location).isUnknown;

/// Pages on the root delegate's stack.
int stackLength() => Fluxy.rootController.rootDelegate.stack.length;
