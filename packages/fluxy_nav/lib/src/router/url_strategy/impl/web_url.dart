import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void removeHash() {
  try {
    setUrlStrategy(PathUrlStrategy());
  } on AssertionError catch (_) {
    debugPrint('[Fluxy] Path URLs must be set before runApp; '
        'keeping hash URLs. Call setUrlStrategy() / create the FluxyDelegate '
        '(showHashOnUrl: false) before runApp.');
  }
}
