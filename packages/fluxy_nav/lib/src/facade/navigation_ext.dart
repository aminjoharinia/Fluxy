import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import '../app/fluxy_root.dart';

/// It replaces the Flutter Navigator, but needs no context.
/// You can to use navigator.push(YourRoute()) rather
/// Navigator.push(context, YourRoute());
NavigatorState? get navigator => FluxyNavigationExt(Fluxy).key.currentState;

extension FluxyNavigationExt on FluxyInterface {
  /// **Navigation.push()** shortcut.<br><br>
  ///
  /// Pushes a new `page` to the stack
  ///
  /// It has the advantage of not needing context,
  /// so you can call from your business logic
  ///
  /// You can set a custom [transition], and a transition [duration].
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// Just like native routing in Flutter, you can push a route
  /// as a [fullscreenDialog],
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// If you want the same behavior of ios that pops a route when the user drag,
  /// you can set [popGesture] to true
  ///
  /// If you're using the [BindingsInterface] api, you must define it here
  ///
  /// By default, GetX will prevent you from push a route that you already in,
  /// if you want to push anyway, set [preventDuplicates] to false
  Future<T?>? to<T extends Object?>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    String? id,
    String? routeName,
    bool fullscreenDialog = false,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
    bool rebuildStack = true,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) {
    return searchDelegate(id).to(
      page,
      opaque: opaque,
      transition: transition,
      curve: curve,
      duration: duration,
      id: id,
      routeName: routeName,
      fullscreenDialog: fullscreenDialog,
      arguments: arguments,
      bindings: bindings,
      preventDuplicates: preventDuplicates,
      popGesture: popGesture,
      showCupertinoParallax: showCupertinoParallax,
      gestureWidth: gestureWidth,
      rebuildStack: rebuildStack,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
    );
  }

  //   FluxyPageBuilder _resolvePage(dynamic page, String method) {
  //     if (page is FluxyPageBuilder) {
  //       return page;
  //     } else if (page is Widget) {
  //       Fluxy.log(
  //           '''WARNING, consider using: "Get.$method(() => Page())"
  //instead of "Get.$method(Page())".
  // Using a widget function instead of a widget fully guarantees that the widget
  //and its controllers will be removed from memory when they are no longer used.
  //       ''');
  //       return () => page;
  //     } else if (page is String) {
  //       throw '''Unexpected String,
  // use toNamed() instead''';
  //     } else {
  //       throw '''Unexpected format,
  // you can only use widgets and widget functions here''';
  //     }
  //   }

  /// **Navigation.pushNamed()** shortcut.<br><br>
  ///
  /// Pushes a new named `page` to the stack.
  ///
  /// It has the advantage of not needing context, so you can call
  /// from your business logic.
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// By default, GetX will prevent you from push a route that you already in,
  /// if you want to push anyway, set [preventDuplicates] to false
  ///
  /// Note: Always put a slash on the route ('/page1'), to avoid unexpected errors
  Future<T?>? toNamed<T>(
    String page, {
    dynamic arguments,
    dynamic id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    // if (preventDuplicates && page == currentRoute) {
    //   return null;
    // }


    return searchDelegate(id).toNamed(
      page,
      arguments: arguments,
      id: id,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  /// **Navigation.pushReplacementNamed()** shortcut.<br><br>
  ///
  /// Pop the current named `page` in the stack and push a new one in its place
  ///
  /// It has the advantage of not needing context, so you can call
  /// from your business logic.
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// By default, GetX will prevent you from push a route that you already in,
  /// if you want to push anyway, set [preventDuplicates] to false
  ///
  /// Note: Always put a slash on the route ('/page1'), to avoid unexpected errors
  Future<T?>? offNamed<T>(
    String page, {
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) {
    // if (preventDuplicates && page == currentRoute) {
    //   return null;
    // }

    return searchDelegate(id).offNamed(
      page,
      arguments: arguments,
      id: id,
      // preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  /// **Navigation.popUntil()** shortcut.<br><br>
  ///
  /// Calls pop several times in the stack until [predicate] returns true
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// [predicate] can be used like this:
  /// `Fluxy.until((route) => Fluxy.currentRoute == '/home')`so when you get to home page,
  ///
  /// or also like this:
  /// `Fluxy.until((route) => !Fluxy.isDialogOpen())`, to make sure the
  /// dialog is closed
  void until(bool Function(FluxyPage<dynamic>) predicate, {String? id}) {
    // if (key.currentState.mounted) // add this if appear problems on future with route navigate
    // when widget don't mounted
    return searchDelegate(id).backUntil(predicate);
  }

  /// **Navigation.pushNamedAndRemoveUntil()** shortcut.<br><br>
  ///
  /// Push the given named `page`, and then pop several pages in the stack
  /// until [predicate] returns true
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// [predicate] can be used like this:
  /// `Fluxy.offNamedUntil(page, ModalRoute.withName('/home'))`
  /// to pop routes in stack until home,
  /// or like this:
  /// `Fluxy.offNamedUntil((route) => !Fluxy.isDialogOpen())`,
  /// to make sure the dialog is closed
  ///
  /// Note: Always put a slash on the route name ('/page1'), to avoid unexpected errors
  Future<T?>? offNamedUntil<T>(
    String page,
    bool Function(FluxyPage<dynamic>)? predicate, {
    String? id,
    dynamic arguments,
    Map<String, String>? parameters,
  }) {

    return searchDelegate(id).offNamedUntil<T>(
      page,
      predicate: predicate,
      id: id,
      arguments: arguments,
      parameters: parameters,
    );
  }

  /// **Navigation.popAndPushNamed()** shortcut.<br><br>
  ///
  /// Pop the current named page and pushes a new `page` to the stack
  /// in its place
  ///
  /// You can send any type of value to the other route in the [arguments].
  /// It is very similar to `offNamed()` but use a different approach
  ///
  /// The `offNamed()` pop a page, and goes to the next. The
  /// `offAndToNamed()` goes to the next page, and removes the previous one.
  /// The route transition animation is different.
  Future<T?>? offAndToNamed<T>(
    String page, {
    dynamic arguments,
    String? id,
    dynamic result,
    Map<String, String>? parameters,
  }) {
    return searchDelegate(
      id,
    ).backAndtoNamed(
      page,
      arguments: arguments,
      result: result,
      parameters: parameters,
    );
  }

  /// **Navigation.removeRoute()** shortcut.<br><br>
  ///
  /// Remove a specific [route] from the stack
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  void removeRoute(String name, {String? id}) {
    return searchDelegate(id).removeRoute(name);
  }

  /// **Navigation.pushNamedAndRemoveUntil()** shortcut.<br><br>
  ///
  /// Push a named `page` and pop several pages in the stack
  /// until [predicate] returns true. [predicate] is optional
  ///
  /// It has the advantage of not needing context, so you can
  /// call from your business logic.
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// [predicate] can be used like this:
  /// `Fluxy.until((route) => Fluxy.currentRoute == '/home')`so when you get to home page,
  /// or also like
  /// `Fluxy.until((route) => !Fluxy.isDialogOpen())`, to make sure the dialog
  /// is closed
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// Note: Always put a slash on the route ('/page1'), to avoid unexpected errors
  Future<T?>? offAllNamed<T>(
    String newRouteName, {
    // bool Function(FluxyPage<dynamic>)? predicate,
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) {

    return searchDelegate(id).offAllNamed<T>(
      newRouteName,
      //predicate: predicate ?? (_) => false,
      arguments: arguments,
      id: id,
      parameters: parameters,
    );
  }

  /// **Navigation.popUntil()** shortcut.<br><br>
  ///
  /// Pop the current page, snackbar, dialog or bottomsheet in the stack
  ///
  /// if your set [closeOverlays] to true, Fluxy.back() will close the
  /// currently open snackbar/dialog/bottomsheet AND the current page
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// It has the advantage of not needing context, so you can call
  /// from your business logic.
  void back<T>({T? result, bool canPop = true, int times = 1, String? id}) {
    if (times < 1) {
      times = 1;
    }

    // Snackbars, dialogs, and bottom sheets are Navigator overlays
    // (PopupRoute), not FluxyPage history. GetX 5 Fluxy.back() previously
    // only called searchDelegate.back() when more than one page was open,
    // so overlays (and sheets on the root page) never closed.
    if (times == 1 && isSnackbarOpen) {
      closeCurrentSnackbar();
      return;
    }

    if (times > 1) {
      // Each open dialog or sheet counts as one step, then pages.
      final delegate = searchDelegate(id);
      var popups = 0;
      delegate.navigatorKey.currentState?.popUntil((route) {
        if (route is PopupRoute && popups < times) {
          popups++;
          return false;
        }
        return true;
      });
      final pages = times - popups;
      if (pages < 1) return;
      var count = 0;
      return delegate.backUntil((route) => count++ == pages);
    } else {
      if (canPop) {
        final delegate = searchDelegate(id);
        final nav = delegate.navigatorKey.currentState;
        if (nav != null) {
          Route<dynamic>? currentRoute;
          nav.popUntil((route) {
            currentRoute = route;
            return true;
          });
          if (currentRoute is PopupRoute) {
            return nav.pop<T>(result);
          }
        }
        if (delegate.canBack == true) {
          return delegate.back<T>(result);
        }
        if (nav?.canPop() == true) {
          return nav!.pop<T>(result);
        }
      } else {
        return searchDelegate(id).back<T>(result);
      }
    }
  }

  /// Pop the current page, snackbar, dialog or bottomsheet in the stack
  ///
  /// if your set [closeOverlays] to true, Fluxy.back() will close the
  /// currently open snackbar/dialog/bottomsheet AND the current page
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// It has the advantage of not needing context, so you can call
  /// from your business logic.
  void backLegacy<T>({
    T? result,
    bool closeOverlays = false,
    bool canPop = true,
    int times = 1,
    String? id,
  }) {
    if (closeOverlays) {
      closeAllOverlays();
    }

    if (times < 1) {
      times = 1;
    }

    if (times > 1) {
      var count = 0;
      return searchDelegate(id).navigatorKey.currentState?.popUntil((route) {
        return count++ == times;
      });
    } else {
      if (canPop) {
        if (searchDelegate(id).navigatorKey.currentState?.canPop() == true) {
          return searchDelegate(id).navigatorKey.currentState?.pop<T>(result);
        }
      } else {
        return searchDelegate(id).navigatorKey.currentState?.pop<T>(result);
      }
    }
  }

  /// **Navigation.pushReplacement()** shortcut .<br><br>
  ///
  /// Pop the current page and pushes a new `page` to the stack
  ///
  /// It has the advantage of not needing context,
  /// so you can call from your business logic
  ///
  /// You can set a custom [transition], define a Tween [curve],
  /// and a transition [duration].
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// Just like native routing in Flutter, you can push a route
  /// as a [fullscreenDialog],
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// If you want the same behavior of ios that pops a route when the user drag,
  /// you can set [popGesture] to true
  ///
  /// If you're using the [BindingsInterface] api, you must define it here
  ///
  /// By default, GetX will prevent you from push a route that you already in,
  /// if you want to push anyway, set [preventDuplicates] to false
  Future<T?>? off<T>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    bool? popGesture,
    String? id,
    String? routeName,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool fullscreenDialog = false,
    bool preventDuplicates = true,
    Duration? duration,
    double Function(BuildContext context)? gestureWidth,
  }) {
    routeName ??= "/${page.runtimeType.toString()}";
    routeName = _cleanRouteName(routeName);
    if (preventDuplicates && routeName == currentRoute) {
      return null;
    }
    return searchDelegate(id).off(
      page,
      opaque: opaque ?? true,
      transition: transition,
      curve: curve,
      popGesture: popGesture,
      id: id,
      routeName: routeName,
      arguments: arguments,
      bindings: bindings,
      fullscreenDialog: fullscreenDialog,
      preventDuplicates: preventDuplicates,
      duration: duration,
      gestureWidth: gestureWidth,
    );
  }

  Future<T?> offUntil<T>(
    Widget Function() page,
    bool Function(FluxyPage) predicate, [
    Object? arguments,
    String? id,
  ]) {
    return searchDelegate(id).offUntil(page, predicate, arguments);
  }

  ///
  /// Push a `page` and pop several pages in the stack
  /// until [predicate] returns true. [predicate] is optional
  ///
  /// It has the advantage of not needing context,
  /// so you can call from your business logic
  ///
  /// You can set a custom [transition], a [curve] and a transition [duration].
  ///
  /// You can send any type of value to the other route in the [arguments].
  ///
  /// Just like native routing in Flutter, you can push a route
  /// as a [fullscreenDialog],
  ///
  /// [predicate] can be used like this:
  /// `Fluxy.until((route) => Fluxy.currentRoute == '/home')`so when you get to home page,
  /// or also like
  /// `Fluxy.until((route) => !Fluxy.isDialogOpen())`, to make sure the dialog
  /// is closed
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  ///
  /// If you want the same behavior of ios that pops a route when the user drag,
  /// you can set [popGesture] to true
  ///
  /// If you're using the [BindingsInterface] api, you must define it here
  ///
  /// By default, GetX will prevent you from push a route that you already in,
  /// if you want to push anyway, set [preventDuplicates] to false
  Future<T?>? offAll<T>(
    Widget Function() page, {
    bool Function(FluxyPage<dynamic>)? predicate,
    bool? opaque,
    bool? popGesture,
    String? id,
    String? routeName,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool fullscreenDialog = false,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    double Function(BuildContext context)? gestureWidth,
  }) {
    routeName ??= "/${page.runtimeType.toString()}";
    routeName = _cleanRouteName(routeName);
    return searchDelegate(id).offAll<T>(
      page,
      predicate: predicate,
      opaque: opaque ?? true,
      popGesture: popGesture,
      id: id,
      //  routeName routeName,
      arguments: arguments,
      bindings: bindings,
      fullscreenDialog: fullscreenDialog,
      transition: transition,
      curve: curve,
      duration: duration,
      gestureWidth: gestureWidth,
    );
  }

  /// Takes a route [name] String generated by [to], [off], [offAll]
  /// (and similar context navigation methods), cleans the extra chars and
  /// accommodates the format.
  /// TODO: check for a more "appealing" URL naming convention.
  /// `() => MyHomeScreenView` becomes `/my-home-screen-view`.
  String _cleanRouteName(String name) {
    name = name.replaceAll('() => ', '');

    /// uncomment for URL styling.
    // name = name.paramCase!;
    if (!name.startsWith('/')) {
      name = '/$name';
    }
    return Uri.tryParse(name)?.toString() ?? name;
  }

  GlobalKey<NavigatorState>? addKey(GlobalKey<NavigatorState> newKey) {
    return rootController.addKey(newKey);
  }

  FluxyDelegate? nestedKey(String? key) {
    return rootController.nestedKey(key);
  }

  FluxyDelegate searchDelegate(String? k) {
    FluxyDelegate key;
    if (k == null) {
      key = Fluxy.rootController.rootDelegate;
    } else {
      if (!keys.containsKey(k)) {
        throw 'Route id ($k) not found';
      }
      key = keys[k]!;
    }

    // if (_key.listenersLength == 0 && !testMode) {
    //   throw """You are trying to use contextless navigation without
    //   a FluxyApp or Fluxy.key.
    //   If you are testing your app, you can use:
    //   [Fluxy.testMode = true], or if you are running your app on
    //   a physical device or emulator, you must exchange your [MaterialApp]
    //   for a [FluxyApp].
    //   """;
    // }

    return key;
  }

  /// give name from current route
  String get currentRoute => routing.current;

  /// give name from previous route
  String get previousRoute => routing.previous;

  /// check a raw current route
  Route<dynamic>? get rawRoute => routing.route;

  /// check if default opaque route is enable
  bool get isOpaqueRouteDefault => defaultOpaqueRoute;

  GlobalKey<NavigatorState> get key => rootController.key;

  Map<String, FluxyDelegate> get keys => rootController.keys;

  FluxyRootState get rootController => FluxyRootState.controller;

  ConfigData get _getxController => FluxyRootState.controller.config;

  bool? get defaultPopGesture => _getxController.defaultPopGesture;
  bool get defaultOpaqueRoute => _getxController.defaultOpaqueRoute;

  Transition? get defaultTransition => _getxController.defaultTransition;

  Duration get defaultTransitionDuration {
    return _getxController.defaultTransitionDuration;
  }

  Curve get defaultTransitionCurve => _getxController.defaultTransitionCurve;

  Curve get defaultDialogTransitionCurve {
    return _getxController.defaultDialogTransitionCurve;
  }

  Duration get defaultDialogTransitionDuration {
    return _getxController.defaultDialogTransitionDuration;
  }

  /// Where the app is: read from the root delegate's stack (`current` is
  /// the top page's path, nested pages included) and the open overlays.
  Routing get routing =>
      FluxyRootState.maybeController?.rootDelegate.routing ?? Routing();

  bool get _shouldUseMock => FluxyTestMode.active && !FluxyRoot.treeInitialized;

  /// give current arguments
  dynamic get arguments {
    return args();
  }

  T args<T>() {
    if (_shouldUseMock) {
      return FluxyTestMode.arguments as T;
    }
    return rootController.rootDelegate.arguments<T>();
  }

  // set parameters(Map<String, String?> newParameters) {
  //   rootController.parameters = newParameters;
  // }

  // @Deprecated('Use FluxyTestMode.active=true instead')
  set testMode(bool isTest) => FluxyTestMode.active = isTest;

  // @Deprecated('Use FluxyTestMode.active instead')
  bool get testMode => FluxyTestMode.active;

  Map<String, String?> get parameters {
    if (_shouldUseMock) {
      return FluxyTestMode.parameters;
    }

    return rootController.rootDelegate.parameters;
  }

  /// Casts the stored router delegate to a desired type
  TDelegate? delegate<TDelegate extends RouterDelegate<TPage>, TPage>() =>
      _getxController.routerDelegate as TDelegate?;
}
