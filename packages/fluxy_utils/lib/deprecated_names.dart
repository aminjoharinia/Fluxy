/// Old GetX-style names, kept as deprecated aliases until Fluxy v1.1.0.
///
/// The extensions (`FluxyStringUtils`, `FluxyNumUtils`, `FluxyDurationUtils`,
/// `FluxyDynamicUtils`) have no alias: only an explicit extension call such as
/// `GetStringUtils(s).isEmail` needs the new name.
library;

import 'fluxy_utils.dart';

@Deprecated('Use FluxyPlatform')
typedef GetPlatform = FluxyPlatform;
@Deprecated('Use FluxyUtils')
typedef GetUtils = FluxyUtils;
@Deprecated('Use FluxyQueue')
typedef GetQueue = FluxyQueue;
@Deprecated('Use FluxyQueueCancelledException')
typedef GetQueueCancelledException = FluxyQueueCancelledException;
@Deprecated('Use FluxyMicrotask')
typedef GetMicrotask = FluxyMicrotask;
