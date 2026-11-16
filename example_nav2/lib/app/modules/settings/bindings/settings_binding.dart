import 'package:fluxy/fluxy.dart';

import '../controllers/settings_controller.dart';

class SettingsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut<SettingsController>(
        () => SettingsController(),
      )
    ];
  }
}
