import 'package:fluxy/fluxy.dart';

import '../controllers/root_controller.dart';

class RootBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut<RootController>(
        () => RootController(),
      )
    ];
  }
}
