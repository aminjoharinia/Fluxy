import 'package:material_ui/material_ui.dart';
import 'package:fluxy/fluxy.dart';

import 'en_US.dart';
import 'pt_BR.dart';

class TranslationService extends Translations {
  static Locale? get locale => Fluxy.deviceLocale;
  static const fallbackLocale = Locale('en', 'US');
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': en_US,
        'pt_BR': pt_BR,
      };
}
