/// Fluxy umbrella package: re-exports every Fluxy package, so existing
/// `import 'package:get/get.dart'` code keeps working.
///
/// New projects can depend on only the packages they need:
/// fluxy_core, fluxy_state, fluxy_nav, fluxy_i18n, fluxy_utils, fluxy_ui.
library;

export 'package:fluxy_core/fluxy_core.dart';
export 'package:fluxy_i18n/fluxy_i18n.dart';
export 'package:fluxy_nav/fluxy_nav.dart';
export 'package:fluxy_state/fluxy_state.dart';
export 'package:fluxy_ui/fluxy_ui.dart';
export 'package:fluxy_utils/fluxy_utils.dart';

