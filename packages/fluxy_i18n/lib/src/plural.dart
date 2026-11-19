/// The CLDR plural categories. A language uses `other` and some of the rest:
/// English `one` / `other`, Persian `one` / `other` (with 0 in `one`),
/// Russian `one` / `few` / `many` / `other`, Arabic all six, Chinese only
/// `other`.
enum PluralCategory { zero, one, two, few, many, other }

/// The CLDR cardinal plural category of [count] in [language] (a language
/// code: `en`, `fa`, `ru`; case and a region part are ignored).
///
/// A built-in table for the common languages, from the CLDR plural rules
/// (unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html);
/// a language not in it follows the English rule. `persian` / `farsi` read as
/// `fa` (the apps' made-up `Locale('persian', 'US')`); `pt_PT` counts like
/// English, other `pt` like French.
PluralCategory pluralCategory(String language, num count) {
  final parts = language.split(RegExp('[_-]'));
  var lang = parts.first.toLowerCase();
  if (lang == 'persian' || lang == 'farsi') lang = 'fa';
  // European Portuguese counts like English; Brazilian like French.
  final rule = lang == 'pt' && parts.skip(1).any((p) => p.toUpperCase() == 'PT')
      ? _oneIfExactlyOne
      : _rules[lang] ?? _oneIfExactlyOne;
  return rule(_Operands(count));
}

/// CLDR operands: n (absolute value), i (integer digits), v (number of
/// visible fraction digits), f (visible fraction digits as an integer).
class _Operands {
  _Operands(num count) {
    final abs = count.abs();
    n = abs;
    i = abs.truncate();
    if (abs is int) {
      v = 0;
      f = 0;
    } else {
      final text = abs.toString();
      final dot = text.indexOf('.');
      final fraction = dot < 0 ? '' : text.substring(dot + 1);
      // 1.0 reads as an integer, as `1` does.
      final digits = fraction.replaceFirst(RegExp(r'0+$'), '');
      v = digits.length;
      f = digits.isEmpty ? 0 : int.parse(digits);
    }
  }

  late final num n;
  late final int i;
  late final int v;
  late final int f;
}

typedef _Rule = PluralCategory Function(_Operands o);

const _one = PluralCategory.one;
const _two = PluralCategory.two;
const _few = PluralCategory.few;
const _many = PluralCategory.many;
const _zero = PluralCategory.zero;
const _other = PluralCategory.other;

bool _inRange(int x, int from, int to) => x >= from && x <= to;

// one: i = 1 and v = 0 (English, German, Italian, Dutch, Swedish…).
PluralCategory _oneIfExactlyOne(_Operands o) =>
    o.i == 1 && o.v == 0 ? _one : _other;

// one: n = 1 (Spanish, Turkish, Hungarian, Greek, Pashto, Sorani, Marathi…).
PluralCategory _oneIfN1(_Operands o) => o.n == 1 ? _one : _other;

// one: i = 0 or n = 1 (Persian, Hindi, Bengali, Gujarati, Kannada, Zulu,
// Amharic).
PluralCategory _oneIfI0OrN1(_Operands o) =>
    o.i == 0 || o.n == 1 ? _one : _other;

// one: i = 0,1 (French, Brazilian Portuguese).
PluralCategory _oneIfI0Or1(_Operands o) => o.i == 0 || o.i == 1 ? _one : _other;

PluralCategory _onlyOther(_Operands o) => _other;

// Russian, Ukrainian, Belarusian.
PluralCategory _eastSlavic(_Operands o) {
  if (o.v != 0) return _other;
  final m10 = o.i % 10, m100 = o.i % 100;
  if (m10 == 1 && m100 != 11) return _one;
  if (_inRange(m10, 2, 4) && !_inRange(m100, 12, 14)) return _few;
  return _many;
}

PluralCategory _polish(_Operands o) {
  if (o.v != 0) return _other;
  if (o.i == 1) return _one;
  final m10 = o.i % 10, m100 = o.i % 100;
  if (_inRange(m10, 2, 4) && !_inRange(m100, 12, 14)) return _few;
  return _many;
}

// Czech, Slovak.
PluralCategory _czech(_Operands o) {
  if (o.v != 0) return _many;
  if (o.i == 1) return _one;
  if (_inRange(o.i, 2, 4)) return _few;
  return _other;
}

PluralCategory _arabic(_Operands o) {
  final n = o.n;
  if (n == 0) return _zero;
  if (n == 1) return _one;
  if (n == 2) return _two;
  if (o.v == 0) {
    final m100 = o.i % 100;
    if (_inRange(m100, 3, 10)) return _few;
    if (_inRange(m100, 11, 99)) return _many;
  }
  return _other;
}

PluralCategory _hebrew(_Operands o) {
  if ((o.i == 1 && o.v == 0) || (o.i == 0 && o.v != 0)) return _one;
  if (o.i == 2 && o.v == 0) return _two;
  return _other;
}

PluralCategory _romanian(_Operands o) {
  if (o.i == 1 && o.v == 0) return _one;
  final m100 = o.i % 100;
  if (o.v != 0 || o.n == 0 || (o.n != 1 && _inRange(m100, 1, 19))) {
    return _few;
  }
  return _other;
}

// Croatian, Serbian, Bosnian.
PluralCategory _southSlavic(_Operands o) {
  final i10 = o.i % 10, i100 = o.i % 100;
  final f10 = o.f % 10, f100 = o.f % 100;
  if ((o.v == 0 && i10 == 1 && i100 != 11) || (f10 == 1 && f100 != 11)) {
    return _one;
  }
  if ((o.v == 0 && _inRange(i10, 2, 4) && !_inRange(i100, 12, 14)) ||
      (_inRange(f10, 2, 4) && !_inRange(f100, 12, 14))) {
    return _few;
  }
  return _other;
}

PluralCategory _lithuanian(_Operands o) {
  if (o.f != 0) return _many;
  final m10 = o.i % 10, m100 = o.i % 100;
  if (m10 == 1 && !_inRange(m100, 11, 19)) return _one;
  if (_inRange(m10, 2, 9) && !_inRange(m100, 11, 19)) return _few;
  return _other;
}

PluralCategory _latvian(_Operands o) {
  final m10 = o.i % 10, m100 = o.i % 100;
  if (o.v == 0 && (m10 == 0 || _inRange(m100, 11, 19))) return _zero;
  if (o.v == 0 && m10 == 1 && m100 != 11) return _one;
  if (o.v != 0) {
    final f10 = o.f % 10, f100 = o.f % 100;
    if (f10 == 1 && f100 != 11) return _one;
    if (f10 == 0 || _inRange(f100, 11, 19)) return _zero;
  }
  return _other;
}

final Map<String, _Rule> _rules = {
  for (final l in ['en', 'de', 'nl', 'sv', 'it', 'fi', 'et', 'ca', 'gl', 'ur',
    'sw', 'bg', 'nb', 'no', 'nn', 'da', 'ast', 'fy', 'yi'])
    l: _oneIfExactlyOne,
  for (final l in ['es', 'tr', 'hu', 'el', 'az', 'ka', 'kk', 'ky', 'mn', 'ps',
    'ckb', 'ku', 'sq', 'ta', 'te', 'ml', 'uz', 'ug', 'eu', 'af', 'so', 'tk',
    'mr'])
    l: _oneIfN1,
  for (final l in ['fa', 'hi', 'bn', 'gu', 'kn', 'zu', 'am', 'as'])
    l: _oneIfI0OrN1,
  for (final l in ['fr', 'pt']) l: _oneIfI0Or1,
  for (final l in ['zh', 'ja', 'ko', 'th', 'vi', 'id', 'ms', 'lo', 'my', 'km',
    'jv', 'yo', 'ig', 'bo', 'dz'])
    l: _onlyOther,
  for (final l in ['ru', 'uk', 'be']) l: _eastSlavic,
  for (final l in ['hr', 'sr', 'bs', 'sh']) l: _southSlavic,
  for (final l in ['cs', 'sk']) l: _czech,
  'pl': _polish,
  'ar': _arabic,
  'he': _hebrew,
  'iw': _hebrew,
  'ro': _romanian,
  'mo': _romanian,
  'lt': _lithuanian,
  'lv': _latvian,
};
