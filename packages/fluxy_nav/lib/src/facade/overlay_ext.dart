import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import 'overlay_pop.dart';

extension OverlayExt on FluxyInterface {
  Future<T> showOverlay<T>({
    required Future<T> Function() asyncFunction,
    Color opacityColor = Colors.black,
    Widget? loadingWidget,
    double opacity = .5,
  }) async {
    final navigatorState = Navigator.of(
      Fluxy.overlayContext!,
      rootNavigator: false,
    );
    final overlayState = navigatorState.overlay!;

    final overlayEntryOpacity = OverlayEntry(
      builder: (context) {
        return Opacity(
          opacity: opacity,
          child: Container(color: opacityColor),
        );
      },
    );
    final overlayEntryLoader = OverlayEntry(
      builder: (context) {
        return loadingWidget ??
            const Center(
              child: SizedBox(height: 90, width: 90, child: Text('Loading...')),
            );
      },
    );
    overlayState.insert(overlayEntryOpacity);
    overlayState.insert(overlayEntryLoader);

    try {
      return await asyncFunction();
    } finally {
      // Also when asyncFunction throws an Error (not only an Exception).
      overlayEntryLoader.remove();
      overlayEntryOpacity.remove();
    }
  }

  /// Returns true if a Snackbar, Dialog or BottomSheet is currently OPEN
  bool get isOverlaysOpen =>
      (isSnackbarOpen || isDialogOpen! || isBottomSheetOpen!);

  /// Returns true if there is no Snackbar, Dialog or BottomSheet open
  bool get isOverlaysClosed =>
      (!isSnackbarOpen && !isDialogOpen! && !isBottomSheetOpen!);

  void closeAllDialogsAndBottomSheets(String? id) {
    while (isDialogOpen! || isBottomSheetOpen!) {
      if (!popTopOverlay(id)) break;
    }
  }

  /// Close the current overlay returning the [result], if provided
  void closeOverlay<T>({String? id, T? result}) {
    popTopOverlay(id, result);
  }

  void closeAllOverlays() {
    closeAllDialogsAndBottomSheets(null);
    closeAllSnackbars();
  }

  /// **Navigation.popUntil()** (with predicate) shortcut .<br><br>
  ///
  /// Close as many routes as defined by [times]
  ///
  /// [id] is for when you are using nested navigation,
  /// as explained in documentation
  void close<T extends Object>({
    bool closeAll = true,
    bool closeSnackbar = true,
    bool closeDialog = true,
    bool closeBottomSheet = true,
    String? id,
    T? result,
  }) {
    void handleClose(
      bool closeCondition,
      Function closeAllFunction,
      Function closeSingleFunction, [
      bool? isOpenCondition,
    ]) {
      if (closeCondition) {
        if (closeAll) {
          closeAllFunction();
        } else if (isOpenCondition == true) {
          closeSingleFunction();
        }
      }
    }

    handleClose(closeSnackbar, closeAllSnackbars, closeCurrentSnackbar);
    handleClose(closeDialog, closeAllDialogs, closeOverlay, isDialogOpen);
    handleClose(
      closeBottomSheet,
      closeAllBottomSheets,
      closeOverlay,
      isBottomSheetOpen,
    );
  }
}
