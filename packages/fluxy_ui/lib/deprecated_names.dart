/// Old GetX-style names, kept as deprecated aliases until Fluxy v1.1.0.
library;

import 'package:fluxy_state/fluxy_state.dart';

import 'fluxy_ui.dart';

@Deprecated('Use FluxyResponsiveView')
typedef GetResponsiveView<T> = FluxyResponsiveView<T>;
@Deprecated('Use FluxyResponsiveWidget')
typedef GetResponsiveWidget<T extends FluxyLifeCycleMixin> =
    FluxyResponsiveWidget<T>;
@Deprecated('Use FluxyResponsiveMixin')
typedef GetResponsiveMixin = FluxyResponsiveMixin;
@Deprecated('Use FluxyAnimatedBuilder')
typedef GetAnimatedBuilder<T> = FluxyAnimatedBuilder<T>;
@Deprecated('Use FluxyAnimatedBuilderState')
typedef GetAnimatedBuilderState<T> = FluxyAnimatedBuilderState<T>;
