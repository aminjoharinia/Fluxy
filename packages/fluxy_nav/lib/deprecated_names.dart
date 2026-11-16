/// Old GetX-style names, kept as deprecated aliases until Fluxy v1.1.0.
///
/// The extensions (`FluxyNavigationExt`, `FluxyResetExt`) have no alias.
library;

import 'fluxy_nav.dart';

@Deprecated('Use FluxyApp')
typedef GetMaterialApp = FluxyApp;
@Deprecated('Use FluxyCupertinoApp')
typedef GetCupertinoApp = FluxyCupertinoApp;
@Deprecated('Use FluxyPage')
typedef GetPage<T> = FluxyPage<T>;
@Deprecated('Use FluxyPageBuilder')
typedef GetPageBuilder = FluxyPageBuilder;
@Deprecated('Use FluxyRouteAwarePageBuilder')
typedef GetRouteAwarePageBuilder<T> = FluxyRouteAwarePageBuilder<T>;
@Deprecated('Use FluxyMiddleware')
typedef GetMiddleware = FluxyMiddleware;
@Deprecated('Use FluxyDelegate')
typedef GetDelegate = FluxyDelegate;
@Deprecated('Use FluxyInformationParser')
typedef GetInformationParser = FluxyInformationParser;
@Deprecated('Use FluxyNavigator')
typedef GetNavigator = FluxyNavigator;
@Deprecated('Use FluxyObserver')
typedef GetObserver = FluxyObserver;
@Deprecated('Use FluxyRouterOutlet')
typedef GetRouterOutlet = FluxyRouterOutlet;
@Deprecated('Use FluxyPageRoute')
typedef GetPageRoute<T> = FluxyPageRoute<T>;
@Deprecated('Use FluxyModalBottomSheetRoute')
typedef GetModalBottomSheetRoute<T> = FluxyModalBottomSheetRoute<T>;
@Deprecated('Use FluxyPageRouteTransitionMixin')
typedef GetPageRouteTransitionMixin<T> = FluxyPageRouteTransitionMixin<T>;
@Deprecated('Use FluxySnackBar')
typedef GetSnackBar = FluxySnackBar;
@Deprecated('Use FluxySnackBarState')
typedef GetSnackBarState = FluxySnackBarState;
@Deprecated('Use FluxyHeroScope')
typedef GetHeroScope = FluxyHeroScope;
@Deprecated('Use FluxyBackGestureController')
typedef GetBackGestureController<T> = FluxyBackGestureController<T>;
@Deprecated('Use FluxyBackGestureDetector')
typedef GetBackGestureDetector<T> = FluxyBackGestureDetector<T>;
@Deprecated('Use FluxyBackGestureDetectorState')
typedef GetBackGestureDetectorState<T> = FluxyBackGestureDetectorState<T>;
