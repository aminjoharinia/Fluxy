/// Language codes usually written right-to-left. Data for an app's own
/// `FluxyApp(directionFor:)`; Fluxy never applies it by itself.
const List<String> rtlLanguages = <String>[
  'ar', // Arabic
  'fa', // Farsi
  'he', // Hebrew
  'ps', // Pashto
  'ur', // Urdu
  'ckb', // Sorani Kurdish
  'dv', // Divehi
  'sd', // Sindhi
  'ug', // Uyghur
  'yi', // Yiddish
];

abstract class Translations {
  Map<String, Map<String, String>> get keys;
}
