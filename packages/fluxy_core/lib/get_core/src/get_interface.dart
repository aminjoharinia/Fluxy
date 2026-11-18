import 'package:flutter/foundation.dart';

import 'log.dart';

/// FluxyInterface allows any auxiliary package to be merged into the [Fluxy]
/// class through extensions
abstract class FluxyInterface {
  bool isLogEnable = kDebugMode;
  LogWriterCallback log = defaultLogWriterCallback;
}
