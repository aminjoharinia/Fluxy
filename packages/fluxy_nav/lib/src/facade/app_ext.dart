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

  /// As a rule, Flutter knows which widget to update,
  /// so this command is rarely needed. We can mention situations
  /// where you use const so that widgets are not updated with setState,
  /// but you want it to be forcefully updated when an event like
  /// language change happens. using context to make the widget dirty
  /// for performRebuild() is a viable solution.
  /// However, in situations where this is not possible, or at least,
  /// is not desired by the developer, the only solution for updating
  /// widgets that Flutter does not want to update is to use reassemble
  /// to forcibly rebuild all widgets. Attention: calling this function will
  /// reconstruct the application from the sketch, use this with caution.
  /// Your entire application will be rebuilt, and touch events will not
  /// work until the end of rendering.
  Future<void> forceAppUpdate() async {
    await engine.performReassemble();
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
