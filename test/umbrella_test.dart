import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy/fluxy.dart';
import 'package:material_ui/material_ui.dart';

// The umbrella package re-exports every Fluxy package; each package has its
// own tests under packages/*/test.
void main() {
  test('one name from each package is reachable through package:fluxy', () {
    expect(Get, isNotNull); // fluxy_core
    expect(0.obs, isA<RxInt>()); // fluxy_state
    expect('k'.tr, 'k'); // fluxy_i18n
    expect(GetUtils.isEmail('a@b.io'), isTrue); // fluxy_utils
    expect(GetPage(name: '/', page: () => const SizedBox()).name, '/'); // nav
    expect(ScreenType.values, isNotEmpty); // fluxy_ui
    expect(Get.reset, isA<Function>()); // moved into fluxy_nav
  });
}
