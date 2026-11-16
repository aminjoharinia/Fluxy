import 'package:flutter/foundation.dart';

import 'log.dart';
import 'smart_management.dart';

/// FluxyInterface allows any auxiliary package to be merged into the [Fluxy]
/// class through extensions
abstract class FluxyInterface {
  SmartManagement smartManagement = SmartManagement.full;
  bool isLogEnable = kDebugMode;
  LogWriterCallback log = defaultLogWriterCallback;
}
