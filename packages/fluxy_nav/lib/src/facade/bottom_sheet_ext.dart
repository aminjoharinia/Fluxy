import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'overlay_pop.dart';

extension ExtensionBottomSheet on FluxyInterface {
  Future<T?> bottomSheet<T>(
    Widget bottomsheet, {
    Color? backgroundColor,
    double? elevation,
    bool persistent = true,
    ShapeBorder? shape,
    Clip? clipBehavior,
    Color? barrierColor,
    bool? ignoreSafeArea,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    RouteSettings? settings,
    Duration? enterBottomSheetDuration,
    Duration? exitBottomSheetDuration,
    Curve? curve,
  }) {
    return Navigator.of(overlayContext!, rootNavigator: useRootNavigator).push(
      FluxyModalBottomSheetRoute<T>(
        builder: (_) => bottomsheet,
        isPersistent: persistent,
        // theme: Theme.of(key.currentContext, shadowThemeOnly: true),
        theme: Theme.of(key.currentContext!),
        isScrollControlled: isScrollControlled,

        barrierLabel: MaterialLocalizations.of(
          key.currentContext!,
        ).modalBarrierDismissLabel,

        backgroundColor: backgroundColor ?? Colors.transparent,
        elevation: elevation,
        shape: shape,
        removeTop: ignoreSafeArea ?? true,
        clipBehavior: clipBehavior,
        isDismissible: isDismissible,
        modalBarrierColor: barrierColor,
        settings: settings,
        enableDrag: enableDrag,
        enterBottomSheetDuration:
            enterBottomSheetDuration ?? const Duration(milliseconds: 250),
        exitBottomSheetDuration:
            exitBottomSheetDuration ?? const Duration(milliseconds: 200),
        curve: curve,
      ),
    );
  }

  void closeBottomSheet<T>({String? id, T? result}) {
    // Stop if there is no bottomsheet open
    if (isBottomSheetOpen == null || !isBottomSheetOpen!) return;

    closeOverlay(id: id, result: result);
  }

  void closeAllBottomSheets({String? id}) {
    while (isBottomSheetOpen!) {
      if (!popTopOverlay(id)) break;
    }
  }

  /// Whether a bottom sheet is open, on any navigator.
  bool? get isBottomSheetOpen => FluxyOverlays.bottomSheets > 0;
}
