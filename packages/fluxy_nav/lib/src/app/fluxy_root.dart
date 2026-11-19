import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_utils/fluxy_utils.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

class ConfigData {
  final ValueChanged<Routing?>? routingCallback;
  final Transition? defaultTransition;
  final VoidCallback? onInit;
  final VoidCallback? onReady;
  final VoidCallback? onDispose;
  final bool? enableLog;
  final LogWriterCallback? logWriterCallback;
  final List<Bind> binds;
  final Duration? transitionDuration;
  final bool? defaultGlobalState;
  final List<FluxyPage>? getPages;
  final FluxyPage? unknownRoute;
  final FluxyRedirect? redirect;
  final RouteInformationProvider? routeInformationProvider;
  final RouteInformationParser<Object>? routeInformationParser;
  final RouterDelegate<Object>? routerDelegate;
  final BackButtonDispatcher? backButtonDispatcher;
  final List<NavigatorObserver>? navigatorObservers;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final Map<String, Map<String, String>>? translationsKeys;
  final Translations? translations;
  final Locale? locale;
  final Locale? fallbackLocale;

  /// Whether a change of the device language (system settings) switches
  /// the app to it through `Fluxy.updateLocale`.
  /// `null` (the default): only when no [locale] was given, so an app that
  /// picks its own language keeps it.
  final bool? followDeviceLocale;
  final String? initialRoute;
  final CustomTransition? customTransition;
  final Widget? home;
  final bool testMode;
  final Key? unikey;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;
  final bool? defaultPopGesture;
  final bool defaultOpaqueRoute;
  final Duration defaultTransitionDuration;
  final Curve defaultTransitionCurve;
  final Curve defaultDialogTransitionCurve;
  final Duration defaultDialogTransitionDuration;
  final Map<String, String?> parameters;
  final SnackBarQueue snackBarQueue = SnackBarQueue();

  ConfigData({
    required this.routingCallback,
    required this.defaultTransition,
    required this.onInit,
    required this.onReady,
    required this.onDispose,
    required this.enableLog,
    required this.logWriterCallback,
    required this.binds,
    required this.transitionDuration,
    required this.defaultGlobalState,
    required this.getPages,
    required this.unknownRoute,
    this.redirect,
    required this.routeInformationProvider,
    required this.routeInformationParser,
    required this.routerDelegate,
    required this.backButtonDispatcher,
    required this.navigatorObservers,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.translationsKeys,
    required this.translations,
    required this.locale,
    required this.fallbackLocale,
    this.followDeviceLocale,
    required this.initialRoute,
    required this.customTransition,
    required this.home,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.unikey,
    this.testMode = false,
    this.defaultOpaqueRoute = true,
    this.defaultTransitionDuration = const Duration(milliseconds: 300),
    this.defaultTransitionCurve = Curves.easeOutQuad,
    this.defaultDialogTransitionCurve = Curves.easeOutQuad,
    this.defaultDialogTransitionDuration = const Duration(milliseconds: 300),
    this.parameters = const {},
    required this.defaultPopGesture,
  });

  ConfigData copyWith({
    ValueChanged<Routing?>? routingCallback,
    Transition? defaultTransition,
    VoidCallback? onInit,
    VoidCallback? onReady,
    VoidCallback? onDispose,
    bool? enableLog,
    LogWriterCallback? logWriterCallback,
    List<Bind>? binds,
    Duration? transitionDuration,
    bool? defaultGlobalState,
    List<FluxyPage>? getPages,
    FluxyPage? unknownRoute,
    FluxyRedirect? redirect,
    RouteInformationProvider? routeInformationProvider,
    RouteInformationParser<Object>? routeInformationParser,
    RouterDelegate<Object>? routerDelegate,
    BackButtonDispatcher? backButtonDispatcher,
    List<NavigatorObserver>? navigatorObservers,
    GlobalKey<NavigatorState>? navigatorKey,
    GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
    Map<String, Map<String, String>>? translationsKeys,
    Translations? translations,
    Locale? locale,
    Locale? fallbackLocale,
    bool? followDeviceLocale,
    String? initialRoute,
    CustomTransition? customTransition,
    Widget? home,
    bool? testMode,
    Key? unikey,
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode? themeMode,
    bool? defaultPopGesture,
    bool? defaultOpaqueRoute,
    Duration? defaultTransitionDuration,
    Curve? defaultTransitionCurve,
    Curve? defaultDialogTransitionCurve,
    Duration? defaultDialogTransitionDuration,
    Map<String, String?>? parameters,
  }) {
    return ConfigData(
      routingCallback: routingCallback ?? this.routingCallback,
      defaultTransition: defaultTransition ?? this.defaultTransition,
      onInit: onInit ?? this.onInit,
      onReady: onReady ?? this.onReady,
      onDispose: onDispose ?? this.onDispose,
      enableLog: enableLog ?? this.enableLog,
      logWriterCallback: logWriterCallback ?? this.logWriterCallback,
      binds: binds ?? this.binds,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      defaultGlobalState: defaultGlobalState ?? this.defaultGlobalState,
      getPages: getPages ?? this.getPages,
      unknownRoute: unknownRoute ?? this.unknownRoute,
      redirect: redirect ?? this.redirect,
      routeInformationProvider:
          routeInformationProvider ?? this.routeInformationProvider,
      routeInformationParser:
          routeInformationParser ?? this.routeInformationParser,
      routerDelegate: routerDelegate ?? this.routerDelegate,
      backButtonDispatcher: backButtonDispatcher ?? this.backButtonDispatcher,
      navigatorObservers: navigatorObservers ?? this.navigatorObservers,
      navigatorKey: navigatorKey ?? this.navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey ?? this.scaffoldMessengerKey,
      translationsKeys: translationsKeys ?? this.translationsKeys,
      translations: translations ?? this.translations,
      locale: locale ?? this.locale,
      fallbackLocale: fallbackLocale ?? this.fallbackLocale,
      followDeviceLocale: followDeviceLocale ?? this.followDeviceLocale,
      initialRoute: initialRoute ?? this.initialRoute,
      customTransition: customTransition ?? this.customTransition,
      home: home ?? this.home,
      testMode: testMode ?? this.testMode,
      unikey: unikey ?? this.unikey,
      theme: theme ?? this.theme,
      darkTheme: darkTheme ?? this.darkTheme,
      themeMode: themeMode ?? this.themeMode,
      defaultPopGesture: defaultPopGesture ?? this.defaultPopGesture,
      defaultOpaqueRoute: defaultOpaqueRoute ?? this.defaultOpaqueRoute,
      defaultTransitionDuration:
          defaultTransitionDuration ?? this.defaultTransitionDuration,
      defaultTransitionCurve:
          defaultTransitionCurve ?? this.defaultTransitionCurve,
      defaultDialogTransitionCurve:
          defaultDialogTransitionCurve ?? this.defaultDialogTransitionCurve,
      defaultDialogTransitionDuration: defaultDialogTransitionDuration ??
          this.defaultDialogTransitionDuration,
      parameters: parameters ?? this.parameters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ConfigData &&
        other.routingCallback == routingCallback &&
        other.defaultTransition == defaultTransition &&
        other.onInit == onInit &&
        other.onReady == onReady &&
        other.onDispose == onDispose &&
        other.enableLog == enableLog &&
        other.logWriterCallback == logWriterCallback &&
        listEquals(other.binds, binds) &&
        other.transitionDuration == transitionDuration &&
        other.defaultGlobalState == defaultGlobalState &&
        listEquals(other.getPages, getPages) &&
        other.unknownRoute == unknownRoute &&
        other.redirect == redirect &&
        other.routeInformationProvider == routeInformationProvider &&
        other.routeInformationParser == routeInformationParser &&
        other.routerDelegate == routerDelegate &&
        other.backButtonDispatcher == backButtonDispatcher &&
        listEquals(other.navigatorObservers, navigatorObservers) &&
        other.navigatorKey == navigatorKey &&
        other.scaffoldMessengerKey == scaffoldMessengerKey &&
        mapEquals(other.translationsKeys, translationsKeys) &&
        other.translations == translations &&
        other.locale == locale &&
        other.fallbackLocale == fallbackLocale &&
        other.followDeviceLocale == followDeviceLocale &&
        other.initialRoute == initialRoute &&
        other.customTransition == customTransition &&
        other.home == home &&
        other.testMode == testMode &&
        other.unikey == unikey &&
        other.theme == theme &&
        other.darkTheme == darkTheme &&
        other.themeMode == themeMode &&
        other.defaultPopGesture == defaultPopGesture &&
        other.defaultOpaqueRoute == defaultOpaqueRoute &&
        other.defaultTransitionDuration == defaultTransitionDuration &&
        other.defaultTransitionCurve == defaultTransitionCurve &&
        other.defaultDialogTransitionCurve == defaultDialogTransitionCurve &&
        other.defaultDialogTransitionDuration ==
            defaultDialogTransitionDuration &&
        mapEquals(other.parameters, parameters);
  }

  @override
  int get hashCode {
    return routingCallback.hashCode ^
        defaultTransition.hashCode ^
        onInit.hashCode ^
        onReady.hashCode ^
        onDispose.hashCode ^
        enableLog.hashCode ^
        logWriterCallback.hashCode ^
        binds.hashCode ^
        transitionDuration.hashCode ^
        defaultGlobalState.hashCode ^
        getPages.hashCode ^
        unknownRoute.hashCode ^
        redirect.hashCode ^
        routeInformationProvider.hashCode ^
        routeInformationParser.hashCode ^
        routerDelegate.hashCode ^
        backButtonDispatcher.hashCode ^
        navigatorObservers.hashCode ^
        navigatorKey.hashCode ^
        scaffoldMessengerKey.hashCode ^
        translationsKeys.hashCode ^
        translations.hashCode ^
        locale.hashCode ^
        fallbackLocale.hashCode ^
        followDeviceLocale.hashCode ^
        initialRoute.hashCode ^
        customTransition.hashCode ^
        home.hashCode ^
        testMode.hashCode ^
        unikey.hashCode ^
        theme.hashCode ^
        darkTheme.hashCode ^
        themeMode.hashCode ^
        defaultPopGesture.hashCode ^
        defaultOpaqueRoute.hashCode ^
        defaultTransitionDuration.hashCode ^
        defaultTransitionCurve.hashCode ^
        defaultDialogTransitionCurve.hashCode ^
        defaultDialogTransitionDuration.hashCode ^
        parameters.hashCode;
  }
}

class FluxyRoot extends StatefulWidget {
  const FluxyRoot({
    super.key,
    required this.config,
    required this.child,
  });
  final ConfigData config;
  final Widget child;
  @override
  State<FluxyRoot> createState() => FluxyRootState();

  static bool get treeInitialized => FluxyRootState._controller != null;

  static FluxyRootState of(BuildContext context) {
    // Handles the case where the input context is a navigator element.
    FluxyRootState? root;
    if (context is StatefulElement && context.state is FluxyRootState) {
      root = context.state as FluxyRootState;
    }
    root = context.findRootAncestorStateOfType<FluxyRootState>() ?? root;
    assert(() {
      if (root == null) {
        throw FlutterError(
          'FluxyRoot operation requested with a context that does not include a FluxyRoot.\n'
          'The context used must be that of a '
          'widget that is a descendant of a FluxyRoot widget.',
        );
      }
      return true;
    }());
    return root!;
  }
}

class FluxyRootState extends State<FluxyRoot> with WidgetsBindingObserver {
  static FluxyRootState? _controller;
  static FluxyRootState? get maybeController => _controller;
  static FluxyRootState get controller {
    if (_controller == null) {
      throw Exception('FluxyRoot is not part of the tree');
    } else {
      return _controller!;
    }
  }

  late ConfigData config;

  @override
  void initState() {
    config = widget.config;
    FluxyRootState._controller = this;
    Engine.instance.addObserver(this);
    onInit();
    super.initState();
  }

  /// The app's `home`, read by the root page: a rebuilt [FluxyApp] with
  /// another `home` shows it, as `MaterialApp(home:)` does.
  late final ValueNotifier<Widget?> _home = ValueNotifier(widget.config.home);

  /// A rebuilt [FluxyApp] (a parent's build, or a test pumping another app
  /// in the same place) keeps its navigation state but takes a new `home`,
  /// new themes and a new `locale` / `fallbackLocale`. A theme set with
  /// `Fluxy.changeTheme` / `changeThemeMode`, or a language set with
  /// `Fluxy.updateLocale`, stays until the app passes a different one.
  @override
  void didUpdateWidget(covariant FluxyRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.config, previous = oldWidget.config;
    _home.value = next.home;
    if (next.theme != previous.theme ||
        next.darkTheme != previous.darkTheme ||
        next.themeMode != previous.themeMode) {
      config = config.copyWith(
        theme: next.theme != previous.theme ? next.theme : null,
        darkTheme: next.darkTheme != previous.darkTheme ? next.darkTheme : null,
        themeMode: next.themeMode != previous.themeMode ? next.themeMode : null,
      );
    }
    // The same rule for the language: a changed `locale` / `fallbackLocale`
    // is applied, and one set with `Fluxy.updateLocale` stays until the app
    // passes a different one. Set now, so this build already uses it (Obx
    // defers its own rebuild while a build is running); then rebuild
    // everything once, as updateLocale does, for `.tr` in const widgets.
    // Translations are not re-read: apps often pass a new `Translations`
    // object on every build, and re-adding them would rebuild every `.tr`.
    var languageChanged = false;
    if (next.locale != previous.locale && next.locale != null) {
      Fluxy.locale = next.locale;
      languageChanged = true;
    }
    if (next.fallbackLocale != previous.fallbackLocale &&
        next.fallbackLocale != null) {
      Fluxy.fallbackLocale = next.fallbackLocale;
      languageChanged = true;
    }
    if (languageChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Fluxy.forceAppUpdate();
      });
    }
  }

  void _reportRouting() {
    final delegate = config.routerDelegate;
    if (delegate is FluxyDelegate) config.routingCallback?.call(delegate.routing);
  }

  void onClose() {
    _home.dispose();
    config.routerDelegate?.removeListener(_reportRouting);
    FluxyOverlays.changes.removeListener(_reportRouting);
    FluxyOverlays.reset();
    config.onDispose?.call();
    Fluxy.clearTranslations();
    config.snackBarQueue.disposeControllers();
    Fluxy.resetInstance();
    _controller = null;
    Engine.instance.removeObserver(this);
  }

  @override
  void dispose() {
    onClose();
    super.dispose();
  }

  void onInit() {
    if (config.getPages == null && config.home == null) {
      throw FlutterError('FluxyApp needs getPages or home.');
    }

    if (config.routerDelegate == null) {
      final newDelegate = FluxyDelegate.createDelegate(
        pages: config.getPages ??
            [
              FluxyPage(
                // The home page is the root of the app.
                name: '/',
                page: () => ValueListenableBuilder<Widget?>(
                  valueListenable: _home,
                  builder: (_, home, _) => home ?? const SizedBox.shrink(),
                ),
              ),
            ],
        notFoundRoute: config.unknownRoute,
        redirect: config.redirect,
        navigatorKey: config.navigatorKey,
        navigatorObservers: config.navigatorObservers,
      );
      config = config.copyWith(routerDelegate: newDelegate);
    }

    final delegate = config.routerDelegate;
    if (delegate is FluxyDelegate && delegate.redirect == null) {
      delegate.redirect = config.redirect;
    }

    // routingCallback hears about page changes and overlays opening or
    // closing, whether FluxyRoot made the delegate or the app passed its own.
    if (config.routingCallback != null) {
      config.routerDelegate!.addListener(_reportRouting);
      FluxyOverlays.changes.addListener(_reportRouting);
    }

    if (config.routeInformationParser == null) {
      final newRouteInformationParser =
          FluxyInformationParser.createInformationParser(
        initialRoute: config.initialRoute ?? config.getPages?.first.name ?? '/',
        // An initialRoute the app asked for wins, even when '/' is a page.
        redirectRootToInitialRoute: config.initialRoute != null ||
            !rootDelegate.routeTable.contains('/'),
      );

      config =
          config.copyWith(routeInformationParser: newRouteInformationParser);
    }

    if (config.locale != null) Fluxy.locale = config.locale;

    if (config.fallbackLocale != null) {
      Fluxy.fallbackLocale = config.fallbackLocale;
    }

    if (config.translations != null) {
      Fluxy.addTranslations(config.translations!.keys);
    } else if (config.translationsKeys != null) {
      Fluxy.addTranslations(config.translationsKeys!);
    }

    config.onInit?.call();

    Fluxy.isLogEnable = config.enableLog ?? kDebugMode;
    Fluxy.log = config.logWriterCallback ?? defaultLogWriterCallback;

    if (config.defaultTransition == null) {
      config = config.copyWith(defaultTransition: getThemeTransition());
    }

    // defaultOpaqueRoute = config.opaqueRoute ?? true;
    // defaultPopGesture = config.popGesture ?? FluxyPlatform.isIOS;
    // defaultTransitionDuration =
    //     config.transitionDuration ?? Duration(milliseconds: 300);

    // After the first frame, as GetX did. A post-frame callback leaves no
    // timer behind (a `Future` did, failing widget tests that pump once).
    Engine.instance.addPostFrameCallback((_) {
      if (mounted) onReady();
    });
  }

  set parameters(Map<String, String?> newParameters) {
    // rootController.parameters = newParameters;
    config = config.copyWith(parameters: newParameters);
  }

  set testMode(bool isTest) {
    config = config.copyWith(testMode: isTest);
    FluxyTestMode.active = isTest;
  }

  void onReady() {
    config.onReady?.call();
  }

  Transition? getThemeTransition() {
    final platform = context.theme.platform;
    final matchingTransition =
        Fluxy.theme.pageTransitionsTheme.builders[platform];
    switch (matchingTransition) {
      case CupertinoPageTransitionsBuilder():
        return Transition.cupertino;
      case ZoomPageTransitionsBuilder():
        return Transition.zoom;
      case FadeUpwardsPageTransitionsBuilder():
        return Transition.fade;
      case OpenUpwardsPageTransitionsBuilder():
        return Transition.native;
      default:
        return null;
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final follow = config.followDeviceLocale ?? config.locale == null;
    if (!follow) return;
    Fluxy.asap(() {
      final locale = Fluxy.deviceLocale;
      if (locale != null) {
        Fluxy.updateLocale(locale);
      }
    });
  }

  void setTheme(ThemeData value) {
    if (config.darkTheme == null) {
      config = config.copyWith(theme: value);
    } else {
      if (value.brightness == Brightness.light) {
        config = config.copyWith(theme: value);
      } else {
        config = config.copyWith(darkTheme: value);
      }
    }
    update();
  }

  void setThemeMode(ThemeMode value) {
    config = config.copyWith(themeMode: value);
    update();
  }

  void restartApp() {
    config = config.copyWith(unikey: UniqueKey());
    update();
  }

  void update() {
    context.visitAncestorElements((element) {
      element.markNeedsBuild();
      return false;
    });
  }

  GlobalKey<NavigatorState> get key => rootDelegate.navigatorKey;

  FluxyDelegate get rootDelegate => config.routerDelegate as FluxyDelegate;

  RouteInformationParser<Object> get informationParser =>
      config.routeInformationParser!;

  GlobalKey<NavigatorState>? addKey(GlobalKey<NavigatorState> newKey) {
    rootDelegate.navigatorKey = newKey;
    return key;
  }

  Map<String, FluxyDelegate> keys = {};

  FluxyDelegate? nestedKey(String? key) {
    if (key == null) {
      return rootDelegate;
    }
    keys.putIfAbsent(
      key,
      () => FluxyDelegate(
        showHashOnUrl: true,
        //debugLabel: 'Getx nested key: ${key.toString()}',
        pages: rootDelegate.routeTable.match(key).page?.children ?? [],
      ),
    );
    return keys[key];
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
