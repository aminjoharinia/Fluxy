import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _changeDeviceLocale(WidgetTester tester) async {
  tester.binding.platformDispatcher
    ..localeTestValue = const Locale('de')
    ..localesTestValue = const [Locale('de')];
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
      ..clearLocaleTestValue()
      ..clearLocalesTestValue();
    Fluxy.reset();
    Fluxy.locale = null;
  });

  testWidgets('an app that sets its own locale keeps it', (tester) async {
    await tester.pumpWidget(FluxyApp(
      locale: const Locale('persian', 'US'),
      home: const SizedBox(),
    ));
    await tester.pumpAndSettle();
    await _changeDeviceLocale(tester);
    expect(Fluxy.locale, const Locale('persian', 'US'));
  });

  testWidgets('an app without a locale follows the device', (tester) async {
    await tester.pumpWidget(const FluxyApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await _changeDeviceLocale(tester);
    expect(Fluxy.locale, const Locale('de'));
  });

  testWidgets('followDeviceLocale: true follows even with a locale',
      (tester) async {
    await tester.pumpWidget(FluxyApp(
      locale: const Locale('persian', 'US'),
      followDeviceLocale: true,
      home: const SizedBox(),
    ));
    await tester.pumpAndSettle();
    await _changeDeviceLocale(tester);
    expect(Fluxy.locale, const Locale('de'));
  });

  testWidgets('followDeviceLocale: false never follows', (tester) async {
    await tester.pumpWidget(const FluxyApp(
      followDeviceLocale: false,
      home: SizedBox(),
    ));
    await tester.pumpAndSettle();
    final before = Fluxy.locale;
    await _changeDeviceLocale(tester);
    expect(Fluxy.locale, before);
  });
}
