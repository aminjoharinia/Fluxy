import '../get_utils/get_utils.dart';

extension FluxyStringUtils on String {
  /// Discover if the String is a valid number
  bool get isNum => FluxyUtils.isNum(this);

  /// Discover if the String is numeric only
  bool get isNumericOnly => FluxyUtils.isNumericOnly(this);

  String numericOnly({bool firstWordOnly = false}) =>
      FluxyUtils.numericOnly(this, firstWordOnly: firstWordOnly);

  /// Discover if the String is alphanumeric only
  bool get isAlphabetOnly => FluxyUtils.isAlphabetOnly(this);

  /// Discover if the String is a boolean
  bool get isBool => FluxyUtils.isBool(this);

  /// Discover if the String is a vector
  bool get isVectorFileName => FluxyUtils.isVector(this);

  /// Discover if the String is a ImageFileName
  bool get isImageFileName => FluxyUtils.isImage(this);

  /// Discover if the String is a AudioFileName
  bool get isAudioFileName => FluxyUtils.isAudio(this);

  /// Discover if the String is a VideoFileName
  bool get isVideoFileName => FluxyUtils.isVideo(this);

  /// Discover if the String is a TxtFileName
  bool get isTxtFileName => FluxyUtils.isTxt(this);

  /// Discover if the String is a Document Word
  bool get isDocumentFileName => FluxyUtils.isWord(this);

  /// Discover if the String is a Document Excel
  bool get isExcelFileName => FluxyUtils.isExcel(this);

  /// Discover if the String is a Document Powerpoint
  bool get isPPTFileName => FluxyUtils.isPPT(this);

  /// Discover if the String is a APK File
  bool get isAPKFileName => FluxyUtils.isAPK(this);

  /// Discover if the String is a PDF file
  bool get isPDFFileName => FluxyUtils.isPDF(this);

  /// Discover if the String is a HTML file
  bool get isHTMLFileName => FluxyUtils.isHTML(this);

  /// Discover if the String is a URL file
  bool get isURL => FluxyUtils.isURL(this);

  /// Discover if the String is a Email
  bool get isEmail => FluxyUtils.isEmail(this);

  /// Discover if the String is a Phone Number
  bool get isPhoneNumber => FluxyUtils.isPhoneNumber(this);

  /// Discover if the String is a DateTime
  bool get isDateTime => FluxyUtils.isDateTime(this);

  /// Discover if the String is a MD5 Hash
  bool get isMD5 => FluxyUtils.isMD5(this);

  /// Discover if the String is a SHA1 Hash
  bool get isSHA1 => FluxyUtils.isSHA1(this);

  /// Discover if the String is a SHA256 Hash
  bool get isSHA256 => FluxyUtils.isSHA256(this);

  /// Discover if the String is a binary value
  bool get isBinary => FluxyUtils.isBinary(this);

  /// Discover if the String is a ipv4
  bool get isIPv4 => FluxyUtils.isIPv4(this);

  bool get isIPv6 => FluxyUtils.isIPv6(this);

  /// Discover if the String is a Hexadecimal
  bool get isHexadecimal => FluxyUtils.isHexadecimal(this);

  /// Discover if the String is a palindrome
  bool get isPalindrome => FluxyUtils.isPalindrome(this);

  /// Discover if the String is a passport number
  bool get isPassport => FluxyUtils.isPassport(this);

  /// Discover if the String is a currency
  bool get isCurrency => FluxyUtils.isCurrency(this);

  /// Discover if the String is a CPF number
  bool get isCpf => FluxyUtils.isCpf(this);

  /// Discover if the String is a CNPJ number
  bool get isCnpj => FluxyUtils.isCnpj(this);

  /// Discover if the String is a case insensitive
  bool isCaseInsensitiveContains(String b) =>
      FluxyUtils.isCaseInsensitiveContains(this, b);

  /// Discover if the String is a case sensitive and contains any value
  bool isCaseInsensitiveContainsAny(String b) =>
      FluxyUtils.isCaseInsensitiveContainsAny(this, b);

  /// capitalize the String
  String get capitalize => FluxyUtils.capitalize(this);

  /// Capitalize the first letter of the String
  String get capitalizeFirst => FluxyUtils.capitalizeFirst(this);

  /// remove all whitespace from the String
  String get removeAllWhitespace => FluxyUtils.removeAllWhitespace(this);

  /// converter the String
  String? get camelCase => FluxyUtils.camelCase(this);

  /// Discover if the String is a valid URL
  String? get paramCase => FluxyUtils.paramCase(this);

  /// add segments to the String
  String createPath([Iterable? segments]) {
    final path = startsWith('/') ? this : '/$this';
    return FluxyUtils.createPath(path, segments);
  }

  /// capitalize only first letter in String words to upper case
  String capitalizeAllWordsFirstLetter() =>
      FluxyUtils.capitalizeAllWordsFirstLetter(this);
}
