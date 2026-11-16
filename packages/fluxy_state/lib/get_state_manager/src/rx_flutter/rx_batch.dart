import 'package:fluxy_core/fluxy_core.dart';

import '../simple/list_notifier.dart';

/// `Get.batch` and `Get.untrack`.
extension FluxyReactiveExt on GetInterface {
  /// Runs [fn] and holds every Rx change made inside it until it returns.
  /// Then each changed Rx notifies **once**, so `ever` / `listen` / streams
  /// and observers see only the final values.
  ///
  /// ```dart
  /// Get.batch(() {
  ///   items.value = newItems;
  ///   total.value = newTotal;
  /// });
  /// ```
  ///
  /// Batches can nest; notifications go out when the outermost one returns.
  /// `Obx` already coalesces rebuilds to one per frame, so the gain is
  /// mostly for workers, streams and listeners that should not see
  /// half-applied state.
  T batch<T>(T Function() fn) => Notifier.instance.batch(fn);

  /// Runs [fn] without subscribing the building `Obx` / `FluxyX` to the Rx
  /// values it reads. For a single value, `rx.peek` does the same.
  T untrack<T>(T Function() fn) => Notifier.instance.untrack(fn);

  /// True while inside [batch].
  bool get isBatching => Notifier.instance.isBatching;
}
