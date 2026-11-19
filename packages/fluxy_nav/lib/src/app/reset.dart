import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';

import 'fluxy_root.dart';

extension FluxyResetExt on FluxyInterface {
  /// Closes every dependency, clears the translations, the locale and the
  /// fallback locale, and forgets theme choices kept for an app not mounted
  /// yet. For tests.
  void reset() {
    Fluxy.resetInstance();
    Fluxy.resetLocales();
    FluxyRootState.clearPendingTheme();
  }
}
