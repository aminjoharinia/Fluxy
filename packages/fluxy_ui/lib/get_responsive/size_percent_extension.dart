import 'dart:ui';

/// Sizes as a percentage of the screen (the app's main view).
extension PercentSized on double {
  static Size get _size {
    final view = PlatformDispatcher.instance.implicitView!;
    return view.physicalSize / view.devicePixelRatio;
  }

  /// `50.0.hp` is 50% of the screen height.
  double get hp => _size.height * (this / 100);

  /// `30.0.wp` is 30% of the screen width.
  double get wp => _size.width * (this / 100);
}
