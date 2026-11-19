/// A small Dart tokenizer for the i18n check: identifiers, string literals
/// (with their value when they hold no interpolation), numbers and
/// punctuation, with line numbers. Comments are skipped. Code inside `${...}`
/// is tokenized too, so a `.tr` inside an interpolation is seen.
library;

enum TokenKind { identifier, string, number, punct }

class Token {
  Token(this.kind, this.text, this.line, {this.value, this.interpolated = false});

  final TokenKind kind;

  /// The source text (for a string: the whole literal, quotes included).
  final String text;
  final int line;

  /// A string literal's value, escapes decoded; null when [interpolated].
  final String? value;
  final bool interpolated;

  bool isPunct(String p) => kind == TokenKind.punct && text == p;
  bool isIdent([String? name]) =>
      kind == TokenKind.identifier && (name == null || text == name);

  @override
  String toString() => '$kind($text)@$line';
}

List<Token> tokenize(String source) => _Lexer(source).run();

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F ||
    c == 0x24;
bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isIdentPart(int c) => _isIdentStart(c) || _isDigit(c);

class _Lexer {
  _Lexer(this.src);

  final String src;
  final tokens = <Token>[];
  int pos = 0;
  int line = 1;

  List<Token> run() {
    _code(untilBrace: false);
    return tokens;
  }

  int _peek([int ahead = 0]) =>
      pos + ahead < src.length ? src.codeUnitAt(pos + ahead) : -1;

  void _advance() {
    if (src.codeUnitAt(pos) == 0x0A) line++;
    pos++;
  }

  /// Code until the end, or until the `}` closing an interpolation.
  void _code({required bool untilBrace}) {
    var depth = 0;
    while (pos < src.length) {
      final c = _peek();
      if (c == 0x0A || c == 0x20 || c == 0x09 || c == 0x0D) {
        _advance();
      } else if (c == 0x2F && _peek(1) == 0x2F) {
        while (pos < src.length && _peek() != 0x0A) {
          pos++;
        }
      } else if (c == 0x2F && _peek(1) == 0x2A) {
        _blockComment();
      } else if ((c == 0x72 || c == 0x52) &&
          (_peek(1) == 0x27 || _peek(1) == 0x22)) {
        pos++; // r
        _string(raw: true);
      } else if (c == 0x27 || c == 0x22) {
        _string(raw: false);
      } else if (_isIdentStart(c)) {
        final start = pos;
        while (pos < src.length && _isIdentPart(_peek())) {
          pos++;
        }
        tokens.add(
            Token(TokenKind.identifier, src.substring(start, pos), line));
      } else if (_isDigit(c)) {
        final start = pos;
        while (pos < src.length &&
            (_isIdentPart(_peek()) || _peek() == 0x2E && _isDigit(_peek(1)))) {
          pos++;
        }
        tokens.add(Token(TokenKind.number, src.substring(start, pos), line));
      } else {
        if (c == 0x7B) depth++;
        if (c == 0x7D) {
          if (untilBrace && depth == 0) {
            pos++;
            return;
          }
          depth--;
        }
        var text = String.fromCharCode(c);
        if (src.startsWith('...', pos)) {
          text = src.startsWith('...?', pos) ? '...?' : '...';
        } else if (src.startsWith('=>', pos) ||
            src.startsWith('==', pos) ||
            src.startsWith('?.', pos) ||
            src.startsWith('??', pos)) {
          text = src.substring(pos, pos + 2);
        }
        tokens.add(Token(TokenKind.punct, text, line));
        pos += text.length;
      }
    }
  }

  void _blockComment() {
    var depth = 0;
    while (pos < src.length) {
      if (_peek() == 0x2F && _peek(1) == 0x2A) {
        depth++;
        pos += 2;
      } else if (_peek() == 0x2A && _peek(1) == 0x2F) {
        depth--;
        pos += 2;
        if (depth == 0) return;
      } else {
        _advance();
      }
    }
  }

  void _string({required bool raw}) {
    final startLine = line;
    final start = raw ? pos - 1 : pos;
    final quote = _peek();
    final triple = _peek(1) == quote && _peek(2) == quote;
    pos += triple ? 3 : 1;
    final value = StringBuffer();
    var interpolated = false;
    while (pos < src.length) {
      final c = _peek();
      if (c == quote && (!triple || (_peek(1) == quote && _peek(2) == quote))) {
        pos += triple ? 3 : 1;
        break;
      }
      if (!triple && c == 0x0A) break; // unterminated
      if (!raw && c == 0x5C) {
        pos++;
        _escape(value);
        continue;
      }
      if (!raw && c == 0x24) {
        if (_peek(1) == 0x7B) {
          interpolated = true;
          pos += 2;
          _code(untilBrace: true);
          continue;
        }
        if (_isIdentStart(_peek(1)) && _peek(1) != 0x24) {
          interpolated = true;
          pos++;
          final idStart = pos;
          while (pos < src.length && _isIdentPart(_peek()) && _peek() != 0x24) {
            pos++;
          }
          tokens.add(Token(
              TokenKind.identifier, src.substring(idStart, pos), line));
          continue;
        }
      }
      value.writeCharCode(c);
      _advance();
    }
    tokens.add(Token(
      TokenKind.string,
      src.substring(start, pos),
      startLine,
      value: interpolated ? null : value.toString(),
      interpolated: interpolated,
    ));
  }

  void _escape(StringBuffer out) {
    if (pos >= src.length) return;
    final c = _peek();
    switch (c) {
      case 0x6E: // n
        out.write('\n');
        pos++;
      case 0x74: // t
        out.write('\t');
        pos++;
      case 0x72: // r
        out.write('\r');
        pos++;
      case 0x62: // b
        out.write('\b');
        pos++;
      case 0x66: // f
        out.write('\f');
        pos++;
      case 0x76: // v
        out.write('\v');
        pos++;
      case 0x78: // xHH
        out.writeCharCode(int.parse(src.substring(pos + 1, pos + 3), radix: 16));
        pos += 3;
      case 0x75: // uHHHH or u{H...}
        if (_peek(1) == 0x7B) {
          final end = src.indexOf('}', pos);
          out.writeCharCode(int.parse(src.substring(pos + 2, end), radix: 16));
          pos = end + 1;
        } else {
          out.writeCharCode(
              int.parse(src.substring(pos + 1, pos + 5), radix: 16));
          pos += 5;
        }
      default:
        out.writeCharCode(c);
        _advance();
    }
  }
}
