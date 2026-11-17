import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'fluxy_root.dart';

/// A Material application configured for GetX navigation and route handling.
///
/// Material types accepted by this widget, including [ThemeData] and
/// [ThemeMode], come from `package:material_ui/material_ui.dart`. Applications
/// using Flutter 3.47 or later should import Material APIs from that package
/// when configuring this widget.
class FluxyApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final Widget? home;
  final Map<String, WidgetBuilder>? routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final InitialRouteListFactory? onGenerateInitialRoutes;
  final RouteFactory? onUnknownRoute;
  final List<NavigatorObserver>? navigatorObservers;
  final TransitionBuilder? builder;
  final String title;
  final GenerateAppTitle? onGenerateTitle;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  final CustomTransition? customTransition;
  final Color? color;
  final Map<String, Map<String, String>>? translationsKeys;
  final Translations? translations;
  final TextDirection? textDirection;
  final Locale? locale;

  /// Whether a change of the device language (system settings) switches
  /// the app to it through `Fluxy.updateLocale`.
  /// `null` (the default): only when no [locale] was given, so an app that
  /// picks its own language keeps it.
  final bool? followDeviceLocale;
  final Locale? fallbackLocale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final LocaleListResolutionCallback? localeListResolutionCallback;
  final LocaleResolutionCallback? localeResolutionCallback;
  final Iterable<Locale> supportedLocales;
  final bool showPerformanceOverlay;
  final bool checkerboardRasterCacheImages;
  final bool checkerboardOffscreenLayers;
  final bool showSemanticsDebugger;
  final bool debugShowCheckedModeBanner;
  final Map<LogicalKeySet, Intent>? shortcuts;
  final ScrollBehavior? scrollBehavior;
  final ThemeData? highContrastTheme;
  final ThemeData? highContrastDarkTheme;
  final Map<Type, Action<Intent>>? actions;
  final bool debugShowMaterialGrid;
  final ValueChanged<Routing?>? routingCallback;
  final Transition? defaultTransition;
  final bool? opaqueRoute;
  final VoidCallback? onInit;
  final VoidCallback? onReady;
  final VoidCallback? onDispose;
  final bool? enableLog;
  final LogWriterCallback? logWriterCallback;
  final bool? popGesture;
  final SmartManagement smartManagement;
  final List<Bind> binds;
  final Duration? transitionDuration;
  final bool? defaultGlobalState;
  final List<FluxyPage>? getPages;
  final FluxyPage? unknownRoute;

  /// Runs before every navigation to an address, including the first one
  /// the app opens at; see [FluxyRedirect]. For example, to send `/` and
  /// unknown addresses to a start page that depends on sign-in:
  /// `redirect: (r) => r.isUnknown || r.path == '/' ? startRoute() : null`.
  final FluxyRedirect? redirect;
  final RouteInformationProvider? routeInformationProvider;
  final RouteInformationParser<Object>? routeInformationParser;
  final RouterDelegate<Object>? routerDelegate;
  final RouterConfig<Object>? routerConfig;
  final BackButtonDispatcher? backButtonDispatcher;
  final bool useInheritedMediaQuery;

  const FluxyApp({
    super.key,
    this.navigatorKey,
    this.scaffoldMessengerKey,
    this.home,
    Map<String, Widget Function(BuildContext)> this.routes =
        const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onGenerateInitialRoutes,
    this.onUnknownRoute,
    this.useInheritedMediaQuery = false,
    List<NavigatorObserver> this.navigatorObservers =
        const <NavigatorObserver>[],
    this.builder,
    this.textDirection,
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.followDeviceLocale,
    this.fallbackLocale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.debugShowMaterialGrid = false,
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.scrollBehavior,
    this.customTransition,
    this.translationsKeys,
    this.translations,
    this.onInit,
    this.onReady,
    this.onDispose,
    this.routingCallback,
    this.defaultTransition,
    this.getPages,
    this.opaqueRoute,
    this.enableLog = kDebugMode,
    this.logWriterCallback,
    this.popGesture,
    this.transitionDuration,
    this.defaultGlobalState,
    this.smartManagement = SmartManagement.full,
    this.binds = const [],
    this.unknownRoute,
    this.redirect,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.actions,
  }) : routeInformationProvider = null,
       backButtonDispatcher = null,
       routeInformationParser = null,
       routerDelegate = null,
       routerConfig = null;

  const FluxyApp.router({
    super.key,
    /// Where the app opens when started at `/`, even when `/` is a page.
    this.initialRoute,
    this.routeInformationProvider,
    this.scaffoldMessengerKey,
    this.routeInformationParser,
    this.routerDelegate,
    this.routerConfig,
    this.backButtonDispatcher,
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.theme,
    this.darkTheme,
    this.useInheritedMediaQuery = false,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.followDeviceLocale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.debugShowMaterialGrid = false,
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.scrollBehavior,
    this.actions,
    this.customTransition,
    this.translationsKeys,
    this.translations,
    this.textDirection,
    this.fallbackLocale,
    this.routingCallback,
    this.defaultTransition,
    this.opaqueRoute,
    this.onInit,
    this.onReady,
    this.onDispose,
    this.enableLog = kDebugMode,
    this.logWriterCallback,
    this.popGesture,
    this.smartManagement = SmartManagement.full,
    this.binds = const [],
    this.transitionDuration,
    this.defaultGlobalState,
    this.getPages,
    this.navigatorObservers,
    this.unknownRoute,
    this.redirect,
  }) : navigatorKey = null,
       onGenerateRoute = null,
       home = null,
       onGenerateInitialRoutes = null,
       onUnknownRoute = null,
       routes = null;

  @override
  Widget build(BuildContext context) {
    return FluxyRoot(
      config: ConfigData(
        backButtonDispatcher: backButtonDispatcher,
        binds: binds,
        customTransition: customTransition,
        defaultGlobalState: defaultGlobalState,
        defaultTransition: defaultTransition,
        enableLog: enableLog,
        fallbackLocale: fallbackLocale,
        getPages: getPages,
        home: home,
        initialRoute: initialRoute,
        locale: locale,
        followDeviceLocale: followDeviceLocale,
        logWriterCallback: logWriterCallback,
        navigatorKey: navigatorKey,
        navigatorObservers: navigatorObservers,
        onDispose: onDispose,
        onInit: onInit,
        onReady: onReady,
        routeInformationParser: routeInformationParser,
        routeInformationProvider: routeInformationProvider,
        routerDelegate: routerDelegate,
        routingCallback: routingCallback,
        scaffoldMessengerKey: scaffoldMessengerKey,
        smartManagement: smartManagement,
        transitionDuration: transitionDuration,
        translations: translations,
        translationsKeys: translationsKeys,
        unknownRoute: unknownRoute,
        redirect: redirect,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        defaultPopGesture: popGesture,
      ),
      // binds: [
      //   Bind.lazyPut<GetMaterialController>(
      //     () => GetMaterialController(

      //     ),
      //     onClose: () {
      //       Fluxy.clearTranslations();
      //       RouterReportManager.dispose();
      //       Fluxy.resetInstance(clearRouteBindings: true);
      //     },
      //   ),
      //   ...binds,
      // ],
      child: Builder(
        builder: (context) {
          final controller = FluxyRoot.of(context);
          return MaterialApp.router(
            routerDelegate: controller.config.routerDelegate,
            routeInformationParser: controller.config.routeInformationParser,
            backButtonDispatcher: backButtonDispatcher,
            routeInformationProvider: routeInformationProvider,
            routerConfig: routerConfig,
            key: controller.config.unikey,
            builder: (context, child) => Directionality(
              textDirection:
                  textDirection ??
                  (rtlLanguages.contains(Fluxy.locale?.languageCode)
                      ? TextDirection.rtl
                      : TextDirection.ltr),
              child: builder == null
                  ? (child ?? const Material())
                  : builder!(context, child ?? const Material()),
            ),
            title: title,
            onGenerateTitle: onGenerateTitle,
            color: color,
            theme: controller.config.theme ?? ThemeData.fallback(),
            darkTheme:
                controller.config.darkTheme ??
                controller.config.theme ??
                ThemeData.fallback(),
            themeMode: controller.config.themeMode,
            locale: Fluxy.locale ?? locale,
            scaffoldMessengerKey: controller.config.scaffoldMessengerKey,
            localizationsDelegates: localizationsDelegates,
            localeListResolutionCallback: localeListResolutionCallback,
            localeResolutionCallback: localeResolutionCallback,
            supportedLocales: supportedLocales,
            debugShowMaterialGrid: debugShowMaterialGrid,
            showPerformanceOverlay: showPerformanceOverlay,
            checkerboardRasterCacheImages: checkerboardRasterCacheImages,
            checkerboardOffscreenLayers: checkerboardOffscreenLayers,
            showSemanticsDebugger: showSemanticsDebugger,
            debugShowCheckedModeBanner: debugShowCheckedModeBanner,
            shortcuts: shortcuts,
            scrollBehavior: scrollBehavior,
          );
        },
      ),
    );
  }
}
