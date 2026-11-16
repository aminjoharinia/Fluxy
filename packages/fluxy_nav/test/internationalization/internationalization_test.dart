import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
import 'package:fluxy_nav/fluxy_nav.dart';

import '../navigation/utils/wrapper.dart';

void main() {
  testWidgets("Get.defaultDialog smoke test", (tester) async {
    await tester.pumpWidget(
      Wrapper(child: Container()),
    );

    await tester.pumpAndSettle();

    expect('covid'.tr, 'Corona Virus');
    expect('total_confirmed'.tr, 'Total Confirmed');
    expect('total_deaths'.tr, 'Total Deaths');

    Fluxy.updateLocale(const Locale('pt', 'BR'));

    await tester.pumpAndSettle();

    expect('covid'.tr, 'Corona Vírus');
    expect('total_confirmed'.tr, 'Total confirmado');
    expect('total_deaths'.tr, 'Total de mortes');

    Fluxy.updateLocale(const Locale('en', 'EN'));

    await tester.pumpAndSettle();

    expect('covid'.tr, 'Corona Virus');
    expect('total_confirmed'.tr, 'Total Confirmed');
    expect('total_deaths'.tr, 'Total Deaths');
  });
}
