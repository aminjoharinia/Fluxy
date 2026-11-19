// Imported on purpose next to package:fluxy: it must not clash (see below).
// ignore: unnecessary_import
import 'dart:ui' show VoidCallback;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy/fluxy.dart';
import 'package:material_ui/material_ui.dart';

// The umbrella package re-exports every Fluxy package; each package has its
// own tests under packages/*/test.
void main() {
  test('one name from each package is reachable through package:fluxy', () {
    expect(Fluxy, isNotNull); // fluxy_core
    expect(0.obs, isA<RxInt>()); // fluxy_state
    expect('k'.tr, 'k'); // fluxy_i18n
    expect(FluxyUtils.isEmail('a@b.io'), isTrue); // fluxy_utils
    expect(FluxyPage(name: '/', page: () => const SizedBox()).name, '/'); // nav
    expect(ScreenType.values, isNotEmpty); // fluxy_ui
    expect(Fluxy.reset, isA<Function>()); // moved into fluxy_nav
  });

  // An app that imports package:fluxy next to another library naming
  // VoidCallback (here dart:ui itself) must compile: Fluxy uses dart:ui's
  // typedef and declares none of its own (APP-NOTES 8).
  test('VoidCallback is dart:ui\'s, so it never clashes', () {
    var calls = 0;
    void run(VoidCallback fn) => fn();
    run(() => calls++);
    expect(calls, 1);
  });
}
