import 'package:flutter/widgets.dart';

/// Kinds of overlay routes [FluxyOverlays] counts.
enum OverlayKind { dialog, bottomSheet }

/// Counts the open dialogs and bottom sheets, on any navigator.
///
/// `Fluxy.isDialogOpen` / `Fluxy.isBottomSheetOpen` read these counts, so
/// they work with any router delegate, without a navigator observer.
abstract final class FluxyOverlays {
  static int _dialogs = 0;
  static int _bottomSheets = 0;

  /// Notifies when an overlay opens or closes.
  static final Listenable changes = _changes;
  static final _changes = _Changes();

  static int get dialogs => _dialogs;
  static int get bottomSheets => _bottomSheets;

  static void _change(OverlayKind kind, int by) {
    switch (kind) {
      case OverlayKind.dialog:
        _dialogs = (_dialogs + by).clamp(0, 1 << 30);
      case OverlayKind.bottomSheet:
        _bottomSheets = (_bottomSheets + by).clamp(0, 1 << 30);
    }
    _changes.notify();
  }

  /// Forgets every count (the app was torn down).
  static void reset() {
    _dialogs = 0;
    _bottomSheets = 0;
  }
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Counts a route in [FluxyOverlays] from the moment it's pushed until it's
/// popped or removed.
mixin CountedOverlay<T> on Route<T> {
  OverlayKind get overlayKind;

  bool _counted = false;

  @override
  void install() {
    super.install();
    if (!_counted) {
      _counted = true;
      FluxyOverlays._change(overlayKind, 1);
    }
  }

  void _uncount() {
    if (!_counted) return;
    _counted = false;
    FluxyOverlays._change(overlayKind, -1);
  }

  @override
  void didComplete(T? result) {
    _uncount();
    super.didComplete(result);
  }

  @override
  void dispose() {
    _uncount();
    super.dispose();
  }
}
