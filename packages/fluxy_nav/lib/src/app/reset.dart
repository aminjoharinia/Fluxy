import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

extension FluxyResetExt on FluxyInterface {
  /// Closes every dependency and clears the translations. For tests.
  void reset() {
    Fluxy.resetInstance();
    Fluxy.clearTranslations();
  }
}
