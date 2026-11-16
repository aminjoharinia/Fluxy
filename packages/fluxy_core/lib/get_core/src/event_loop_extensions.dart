import 'dart:async';

import 'get_interface.dart';

extension LoopEventsExt on FluxyInterface {
  Future<T> toEnd<T>(FutureOr<T> Function() computation) async {
    await Future.delayed(Duration.zero);
    final val = computation();
    return val;
  }

  FutureOr<T> asap<T>(T Function() computation,
      {bool Function()? condition}) async {
    T val;
    if (condition == null || !condition()) {
      await Future.delayed(Duration.zero);
      val = computation();
    } else {
      val = computation();
    }
    return val;
  }
}
