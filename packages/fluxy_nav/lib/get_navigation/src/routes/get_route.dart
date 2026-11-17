// ignore_for_file: overridden_fields

import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fluxy_state/fluxy_state.dart';
import '../../get_navigation.dart';

class FluxyPage<T> extends Page<T> {
  final FluxyPageBuilder page;
  final bool? popGesture;
  final Map<String, String>? parameters;
  final String? title;
  final Transition? transition;
  final Curve curve;
  final bool? participatesInRootNavigator;
  final Alignment? alignment;
  final bool maintainState;
  final bool opaque;
  final double Function(BuildContext context)? gestureWidth;
  final BindingsInterface? binding;
  final List<BindingsInterface> bindings;
  final List<Bind> binds;
  final CustomTransition? customTransition;
  final Duration? transitionDuration;
  final Duration? reverseTransitionDuration;
  final bool fullscreenDialog;
  final bool preventDuplicates;
  final Completer<T?>? completer;
  // @override
  // final LocalKey? key;

  // @override
  // RouteSettings get settings => this;

  @override
  final Object? arguments;

  @override
  final String name;

  final bool inheritParentPath;

  final List<FluxyPage> children;
  final List<FluxyMiddleware> middlewares;
  final FluxyPage? unknownRoute;
  final bool showCupertinoParallax;

  final PreventDuplicateHandlingMode preventDuplicateHandlingMode;

  static void _defaultPopInvokedHandler(bool didPop, Object? result) {}

  FluxyPage({
    required this.name,
    required this.page,
    this.title,
    this.participatesInRootNavigator,
    this.gestureWidth,
    // RouteSettings settings,
    this.maintainState = true,
    this.curve = Curves.linear,
    this.alignment,
    this.parameters,
    this.opaque = true,
    this.transitionDuration,
    this.reverseTransitionDuration,
    this.popGesture,
    this.binding,
    this.bindings = const [],
    this.binds = const [],
    this.transition,
    this.customTransition,
    this.fullscreenDialog = false,
    this.children = const <FluxyPage>[],
    this.middlewares = const [],
    this.unknownRoute,
    this.arguments,
    this.showCupertinoParallax = true,
    this.preventDuplicates = true,
    this.preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
    this.completer,
    this.inheritParentPath = true,
    LocalKey? key,
    super.canPop,
    super.onPopInvoked = _defaultPopInvokedHandler,
    super.restorationId,
  })  : assert(name.startsWith('/'),
            'It is necessary to start route name [$name] with a slash: /$name'),
        super(
          key: key ?? ValueKey(name),
          name: name,
          // arguments: Fluxy.arguments,
        );
  // settings = RouteSettings(name: name, arguments: Fluxy.arguments);

  FluxyPage<T> copyWith({
    LocalKey? key,
    String? name,
    FluxyPageBuilder? page,
    bool? popGesture,
    Map<String, String>? parameters,
    String? title,
    Transition? transition,
    Curve? curve,
    Alignment? alignment,
    bool? maintainState,
    bool? opaque,
    List<BindingsInterface>? bindings,
    BindingsInterface? binding,
    List<Bind>? binds,
    CustomTransition? customTransition,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    bool? fullscreenDialog,
    RouteSettings? settings,
    List<FluxyPage<T>>? children,
    FluxyPage? unknownRoute,
    List<FluxyMiddleware>? middlewares,
    bool? preventDuplicates,
    PreventDuplicateHandlingMode? preventDuplicateHandlingMode,
    double Function(BuildContext context)? gestureWidth,
    bool? participatesInRootNavigator,
    Object? arguments,
    bool? showCupertinoParallax,
    Completer<T?>? completer,
    bool? inheritParentPath,
    bool? canPop,
    PopInvokedWithResultCallback<T>? onPopInvoked,
    String? restorationId,
  }) {
    return FluxyPage(
      key: key ?? this.key,
      participatesInRootNavigator:
          participatesInRootNavigator ?? this.participatesInRootNavigator,
      preventDuplicates: preventDuplicates ?? this.preventDuplicates,
      preventDuplicateHandlingMode:
          preventDuplicateHandlingMode ?? this.preventDuplicateHandlingMode,
      name: name ?? this.name,
      page: page ?? this.page,
      popGesture: popGesture ?? this.popGesture,
      parameters: parameters ?? this.parameters,
      title: title ?? this.title,
      transition: transition ?? this.transition,
      curve: curve ?? this.curve,
      alignment: alignment ?? this.alignment,
      maintainState: maintainState ?? this.maintainState,
      opaque: opaque ?? this.opaque,
      bindings: bindings ?? this.bindings,
      binds: binds ?? this.binds,
      binding: binding ?? this.binding,
      customTransition: customTransition ?? this.customTransition,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      reverseTransitionDuration:
          reverseTransitionDuration ?? this.reverseTransitionDuration,
      fullscreenDialog: fullscreenDialog ?? this.fullscreenDialog,
      children: children ?? this.children,
      unknownRoute: unknownRoute ?? this.unknownRoute,
      middlewares: middlewares ?? this.middlewares,
      gestureWidth: gestureWidth ?? this.gestureWidth,
      arguments: arguments ?? this.arguments,
      showCupertinoParallax:
          showCupertinoParallax ?? this.showCupertinoParallax,
      completer: completer ?? this.completer,
      inheritParentPath: inheritParentPath ?? this.inheritParentPath,
      canPop: canPop ?? this.canPop,
      onPopInvoked: onPopInvoked ?? this.onPopInvoked,
      restorationId: restorationId ?? this.restorationId,
    );
  }

  @override
  Route<T> createRoute(BuildContext context) {
    // return FluxyPageRoute<T>(settings: this, page: page);
    final page = PageRedirect(
      route: this,
      settings: this,
      unknownRoute: unknownRoute,
    ).getPageToRoute<T>(this, unknownRoute, context);

    return page;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FluxyPage<T> && other.key == key;
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'Page')}("$name", $key, $arguments)';

  @override
  int get hashCode {
    return key.hashCode;
  }
}
