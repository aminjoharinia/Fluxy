/// Old GetX-style names, kept as deprecated aliases until Fluxy v1.1.0.
library;

import 'fluxy_core.dart';

/// The same object as [Fluxy].
@Deprecated('Use Fluxy')
// ignore: non_constant_identifier_names
final Get = Fluxy;

@Deprecated('Use FluxyInterface')
typedef GetInterface = FluxyInterface;
