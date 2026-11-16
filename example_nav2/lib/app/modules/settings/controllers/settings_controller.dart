import 'package:fluxy/fluxy.dart';

class SettingsController extends FluxyController {
  final count = 0.obs;
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {}
  void increment() => count.value++;
}
