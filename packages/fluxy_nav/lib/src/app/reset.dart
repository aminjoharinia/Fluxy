import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension FluxyResetExt on FluxyInterface {
  void reset({bool clearRouteBindings = true}) {
    Fluxy.resetInstance(clearRouteBindings: clearRouteBindings);
    // Fluxy.clearRouteTree();
    Fluxy.clearTranslations();
    // Fluxy.resetRootNavigator();
  }
}
