import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension GetResetExt on GetInterface {
  void reset({bool clearRouteBindings = true}) {
    Get.resetInstance(clearRouteBindings: clearRouteBindings);
    // Get.clearRouteTree();
    Get.clearTranslations();
    // Get.resetRootNavigator();
  }
}
