@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_utils/fluxy_utils.dart';

void main() {
  test('Platform test', () {
    expect(FluxyPlatform.isAndroid, Platform.isAndroid);
    expect(FluxyPlatform.isIOS, Platform.isIOS);
    expect(FluxyPlatform.isFuchsia, Platform.isFuchsia);
    expect(FluxyPlatform.isLinux, Platform.isLinux);
    expect(FluxyPlatform.isMacOS, Platform.isMacOS);
    expect(FluxyPlatform.isWindows, Platform.isWindows);
    expect(FluxyPlatform.isWeb, false);
  });
}
