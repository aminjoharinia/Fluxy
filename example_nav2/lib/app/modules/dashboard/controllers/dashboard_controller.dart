import 'dart:async';

import 'package:fluxy/fluxy.dart';

class DashboardController extends FluxyController {
  final now = DateTime.now().obs;
  Timer? _clock;

  @override
  void onReady() {
    super.onReady();
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        now.value = DateTime.now();
      },
    );
  }

  @override
  void onClose() {
    _clock?.cancel();
    super.onClose();
  }
}
