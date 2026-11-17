import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

/// The page names on the root delegate's stack, bottom first.
List<String?> stackNames() =>
    Fluxy.rootController.rootDelegate.stack.entries.map((e) => e.name).toList();
