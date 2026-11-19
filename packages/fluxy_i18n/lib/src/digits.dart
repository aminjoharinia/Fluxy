import 'dart:ui';

import 'locales.dart';
import 'lookup.dart';

/// The zero digit of each native digit set (the other nine follow it).
const int _arabicIndic = 0x0660; // ٠ Arabic
const int _extendedArabicIndic = 0x06F0; // ۰ Persian, Urdu, Pashto
const int _devanagari = 0x0966; // ०
const int _bengali = 0x09E6; // ০
const int _myanmar = 0x1040; // ၀

/// Native digit sets, so [westernDigits] can read any of them back.
const List<int> _nativeZeros = [
  _arabicIndic, _extendedArabicIndic, _devanagari, _bengali, _myanmar,
  0x07C0, // N'Ko
  0x0AE6, // Gujarati
  0x0A66, // Gurmukhi
  0x0B66, // Oriya
  0x0BE6, // Tamil
  0x0C66, // Telugu
  0x0CE6, // Kannada
  0x0D66, // Malayalam
  0x0E50, // Thai
  0x0ED0, // Lao
  0x0F20, // Tibetan
  0x17E0, // Khmer
  0xFF10, // fullwidth
];

/// The zero of the digits [locale] writes numbers with by default (CLDR
/// default numbering system), or null for Western digits.
///
/// Persian (also `persian` / `farsi`) and Pashto: Extended Arabic-Indic
/// (۰۱۲); Arabic and Sorani: Arabic-Indic (٠١٢), except Arabic in the
/// Maghreb (MA, DZ, TN, LY, EH), which uses Western digits; Marathi and
/// Nepali: Devanagari; Bengali; Burmese. Everything else, Urdu and Hindi
/// included (their CLDR default is Western), keeps Western digits.
int? nativeZeroFor(Locale? locale) {
  if (locale == null) return null;
  final key = LocaleKey.of(locale);
  return switch (key.language) {
    'fa' || 'persian' || 'farsi' || 'ps' => _extendedArabicIndic,
    'ar' => const {'MA', 'DZ', 'TN', 'LY', 'EH'}.contains(key.country)
        ? null
        : _arabicIndic,
    'ckb' => _arabicIndic,
    'mr' || 'ne' => _devanagari,
    'bn' => _bengali,
    'my' => _myanmar,
    _ => null,
  };
}

String _mapDigits(String text, int Function(int code) map) {
  final codes = text.codeUnits;
  List<int>? out;
  for (var i = 0; i < codes.length; i++) {
    final mapped = map(codes[i]);
    if (mapped != codes[i]) {
      out ??= List.of(codes);
      out[i] = mapped;
    }
  }
  return out == null ? text : String.fromCharCodes(out);
}

extension LocalDigits on String {
  /// This text with its Western digits (0-9) written in the digits of
  /// [locale] (default: `Fluxy.locale`, read reactively, so an `Obx`
  /// showing it follows the language): `'12:30'.localDigits()` is `۱۲:۳۰`
  /// in Persian, unchanged in English. See [nativeZeroFor] for which
  /// languages have native digits.
  String localDigits([Locale? locale]) {
    final zero = nativeZeroFor(locale ?? FluxyLocales.instance.locale);
    if (zero == null) return this;
    return _mapDigits(
        this, (c) => c >= 0x30 && c <= 0x39 ? zero + (c - 0x30) : c);
  }

  /// This text with every native digit (Persian, Arabic, Devanagari,
  /// Bengali, Thai, fullwidth…) turned into Western 0-9, for parsing what
  /// people type: `int.parse('۱۲۳'.westernDigits)`.
  String get westernDigits => _mapDigits(this, (c) {
        for (final zero in _nativeZeros) {
          if (c >= zero && c <= zero + 9) return 0x30 + (c - zero);
        }
        return c;
      });
}

extension LocalDigitsNum on num {
  /// `toString()` in the digits of [locale] (default `Fluxy.locale`); see
  /// [LocalDigits.localDigits].
  String localDigits([Locale? locale]) => toString().localDigits(locale);
}
