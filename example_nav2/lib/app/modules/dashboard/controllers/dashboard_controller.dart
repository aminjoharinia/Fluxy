import 'dart:async';

import 'package:fluxy/fluxy.dart';

class DashboardController extends FluxyController {
  final now = DateTime.now().obs;
  @override
  void onReady() {
    super.onReady();
    Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        now.value = DateTime.now();
      },
    );
  }
}
