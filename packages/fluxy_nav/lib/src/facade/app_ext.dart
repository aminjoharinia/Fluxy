import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import '../app/fluxy_root.dart';

/// App-wide state: locale, theme, the root context.
extension FluxyAppExt on FluxyInterface {
  /// Switches the app to [l].
  ///
  /// Every `Obx` showing `.tr` text updates on its own. With [rebuildAll]
  /// (the default) the whole app is also rebuilt through
  /// [forceAppUpdate], because a widget that reads `.tr` in a plain `build`
  /// method has no other way to learn that the language changed. Pass
  /// `rebuildAll: false` only when all translated text is inside `Obx` (or
  /// rebuilt some other way).
  Future<void> updateLocale(Locale l, {bool rebuildAll = true}) async {
    Fluxy.locale = l;
    if (rebuildAll) {
      await forceAppUpdate();
    } else {
      appUpdate();
    }
  }

  /// Rebuilds every widget of the app once, `const` ones included, for text
  /// read outside an `Obx` (a `.tr` in a plain `build`) after the language
  /// changed. Completes after that frame.
  ///
  /// It marks every element for a rebuild; unlike the hot-reload hook GetX
  /// used (`performReassemble`), it doesn't call `State.reassemble` or force
  /// a new layout and paint of every render object. Called while a frame is
  /// being built, it waits for the end of that frame.
  Future<void> forceAppUpdate() async {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      await binding.endOfFrame;
    }
    final root = binding.rootElement;
    if (root == null) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    mark(root);
    await binding.endOfFrame;
  }

  void appUpdate() => rootController.update();

  /// Changes the active application theme to [theme].
  ///
  /// [ThemeData] is the type exported by
  /// `package:material_ui/material_ui.dart`.
  ///
  /// Called before a [FluxyApp] is mounted (during boot), the theme is kept
  /// and applied when the app mounts.
  void changeTheme(ThemeData theme) {
    FluxyRootState.changeTheme(theme);
  }

  /// Changes whether the light or dark application theme is active.
  ///
  /// [ThemeMode] is the type exported by
  /// `package:material_ui/material_ui.dart`.
  ///
  /// Called before a [FluxyApp] is mounted (during boot), the mode is kept
  /// and applied when the app mounts.
  void changeThemeMode(ThemeMode themeMode) {
    FluxyRootState.changeThemeMode(themeMode);
  }

  /// give access to currentContext
  BuildContext? get context =>
      FluxyRootState.maybeController?.key.currentContext;

  /// give access to current Overlay Context
  BuildContext? get overlayContext {
    final nav = FluxyRootState.maybeController?.key.currentState;
    if (nav == null) return null;
    BuildContext? overlay;
    nav.overlay?.context.visitChildElements((element) {
      overlay = element;
    });
    return overlay;
  }

  /// give access to Theme.of(context)
  ThemeData get theme {
    var theme = ThemeData.fallback();
    if (context != null) {
      theme = Theme.of(context!);
    }
    return theme;
  }
}
