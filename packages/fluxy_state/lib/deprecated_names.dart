/// Old GetX-style names, kept as deprecated aliases until Fluxy v1.1.0.
///
/// `dart run tool/migrate.dart <app>` (in the Fluxy repo) or `dart fix --apply`
/// moves an app to the new names.
library;

import 'fluxy_state.dart';

@Deprecated('Use FluxyController')
typedef GetxController = FluxyController;
@Deprecated('Use FluxyService')
typedef GetxService = FluxyService;
@Deprecated('Use FluxyServiceMixin')
typedef GetxServiceMixin = FluxyServiceMixin;
@Deprecated('Use FluxyLifeCycleMixin')
typedef GetLifeCycleMixin = FluxyLifeCycleMixin;
@Deprecated('Use FluxyView')
typedef GetView<T> = FluxyView<T>;
@Deprecated('Use FluxyWidget')
typedef GetWidget<S extends FluxyLifeCycleMixin> = FluxyWidget<S>;
@Deprecated('Use FluxyBuilder')
typedef GetBuilder<T extends FluxyController> = FluxyBuilder<T>;
@Deprecated('Use FluxyControllerBuilder')
typedef GetControllerBuilder<T extends FluxyLifeCycleMixin> =
    FluxyControllerBuilder<T>;
@Deprecated('Use FluxyX')
typedef GetX<T extends FluxyLifeCycleMixin> = FluxyX<T>;
@Deprecated('Use FluxyXState')
typedef GetXState<T extends FluxyLifeCycleMixin> = FluxyXState<T>;
@Deprecated('Use FluxyXControllerBuilder')
typedef GetXControllerBuilder<T extends FluxyLifeCycleMixin> =
    FluxyXControllerBuilder<T>;
@Deprecated('Use FluxyStatus')
typedef GetStatus<T> = FluxyStatus<T>;
@Deprecated('Use FluxyListenable')
typedef GetListenable<T> = FluxyListenable<T>;
@Deprecated('Use FluxyNotifier')
typedef GetNotifier<T> = FluxyNotifier<T>;
@Deprecated('Use FluxyTickerProviderStateMixin')
typedef GetTickerProviderStateMixin = FluxyTickerProviderStateMixin;
@Deprecated('Use FluxySingleTickerProviderStateMixin')
typedef GetSingleTickerProviderStateMixin = FluxySingleTickerProviderStateMixin;
