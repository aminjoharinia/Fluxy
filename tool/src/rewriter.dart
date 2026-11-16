/// Applies a [RenameMap] to one Dart source file.
///
/// A small scanner, not a parser: it knows comments (line, doc, nested
/// block), string literals (single / double quoted, triple, raw) and string
/// interpolation, so names inside comments and strings are left alone while
/// names inside `${...}` / `$name` are rewritten. It does not resolve names:
/// a local declaration that shadows an old name is renamed too.
library;

import 'rename_map.dart';

/// The rewritten source and how many replacements were made.
class RewriteResult {
  RewriteResult(this.source, this.changes);

  final String source;
  final int changes;
}

/// Rewrites [source] with [map].
RewriteResult rewrite(String source, RenameMap map) {
  final scanner = _Scanner(source, map);
  scanner.code(topLevel: true);
  return RewriteResult(scanner.out.toString(), scanner.changes);
}

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F || // _
    c == 0x24; // $

bool _isIdentPart(int c) => _isIdentStart(c) || (c >= 0x30 && c <= 0x39);

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

const _directives = {'import', 'export', 'part'};

class _Scanner {
  _Scanner(this.s, this.map);

  final String s;
  final RenameMap map;
  final StringBuffer out = StringBuffer();
  int i = 0;
  int changes = 0;

  int _at(int j) => j < s.length ? s.codeUnitAt(j) : -1;

  /// Copies code up to the end of input, or (inside `${`) up to and
  /// including the `}` that closes it.
  void code({bool topLevel = false}) {
    var depth = 0;
    // Inside an import / export / part directive (top level, up to `;`).
    var inDirective = false;
    // The last code character that was not a space, for directive starts.
    var last = -1;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      final next = _at(i + 1);
      if (c == 0x2F && next == 0x2F) {
        _lineComment();
        continue;
      }
      if (c == 0x2F && next == 0x2A) {
        _blockComment();
        continue;
      }
      if (c == 0x27 || c == 0x22) {
        _string(raw: false, directive: inDirective);
        last = c;
        continue;
      }
      if (_isIdentStart(c) && (i == 0 || !_isIdentPart(s.codeUnitAt(i - 1)))) {
        final start = i;
        while (i < s.length && _isIdentPart(s.codeUnitAt(i))) {
          i++;
        }
        final word = s.substring(start, i);
        if (word == 'r' && (_at(i) == 0x27 || _at(i) == 0x22)) {
          out.write('r');
          _string(raw: true, directive: inDirective);
          last = 0x27;
          continue;
        }
        if (topLevel &&
            depth == 0 &&
            _directives.contains(word) &&
            (last == -1 || last == 0x3B || last == 0x7D)) {
          inDirective = true;
        }
        _identifier(start, word, afterDot: last == 0x2E);
        last = 0x61;
        continue;
      }
      if (c == 0x7B) {
        depth++;
      } else if (c == 0x7D) {
        if (!topLevel && depth == 0) {
          out.writeCharCode(c);
          i++;
          return;
        }
        depth--;
      } else if (c == 0x3B) {
        inDirective = false;
      }
      if (!_isSpace(c)) last = c;
      out.writeCharCode(c);
      i++;
    }
  }

  void _lineComment() {
    final end = s.indexOf('\n', i);
    final stop = end < 0 ? s.length : end;
    out.write(s.substring(i, stop));
    i = stop;
  }

  void _blockComment() {
    final start = i;
    var depth = 0;
    while (i < s.length) {
      if (s.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (s.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth == 0) break;
      } else {
        i++;
      }
    }
    out.write(s.substring(start, i));
  }

  /// Copies a string literal starting at its opening quote. In a directive,
  /// a plain literal is matched against the URI pairs.
  void _string({required bool raw, required bool directive}) {
    final quote = s[i];
    final triple = s.startsWith(quote * 3, i);
    final delimiter = triple ? quote * 3 : quote;
    if (directive && !triple && _directiveUri(quote, raw)) return;
    out.write(delimiter);
    i += delimiter.length;
    while (i < s.length) {
      if (s.startsWith(delimiter, i)) {
        out.write(delimiter);
        i += delimiter.length;
        return;
      }
      final c = s.codeUnitAt(i);
      if (!triple && c == 0x0A) return; // unterminated: stop at the line end
      if (!raw && c == 0x5C) {
        // An escape: copy it and the escaped character as they are.
        final end = (i + 2).clamp(0, s.length);
        out.write(s.substring(i, end));
        i = end;
        continue;
      }
      if (!raw && c == 0x24) {
        final next = _at(i + 1);
        if (next == 0x7B) {
          out.write(r'${');
          i += 2;
          code(); // up to and including the closing `}`
          continue;
        }
        if (_isIdentStart(next) && next != 0x24) {
          out.write(r'$');
          final start = ++i;
          while (i < s.length &&
              _isIdentPart(s.codeUnitAt(i)) &&
              s.codeUnitAt(i) != 0x24) {
            i++;
          }
          final word = s.substring(start, i);
          final rename = map.words[word];
          if (rename != null) {
            out.write(rename.to);
            changes++;
          } else {
            out.write(word);
          }
          continue;
        }
      }
      out.writeCharCode(c);
      i++;
    }
  }

  /// Rewrites the one-line literal at [i] if it is a URI in the map.
  bool _directiveUri(String quote, bool raw) {
    final end = s.indexOf(quote, i + 1);
    if (end < 0) return false;
    final uri = s.substring(i + 1, end);
    if (uri.contains('\n') ||
        (!raw && (uri.contains(r'$') || uri.contains('\\')))) {
      return false;
    }
    final rewritten = map.rewriteUri(uri);
    if (rewritten == null) return false;
    out
      ..write(quote)
      ..write(rewritten)
      ..write(quote);
    i = end + 1;
    changes++;
    return true;
  }

  /// Writes the identifier [word] that starts at [start] (already consumed),
  /// or its replacement. [afterDot]: the code before it (comments skipped)
  /// ends with a `.`, so it is a member of something else: `foo.Get.back`
  /// is not `Get.back`.
  void _identifier(int start, String word, {required bool afterDot}) {
    final candidates = map.members[word];
    if (candidates != null && !afterDot) {
      for (final rename in candidates) {
        final end = _matchMember(start, rename);
        if (end != null) {
          out.write(rename.to);
          i = end;
          changes++;
          return;
        }
      }
    }
    final rename = map.words[word];
    if (rename != null) {
      out.write(rename.to);
      changes++;
    } else {
      out.write(word);
    }
  }

  /// The end of a match of [rename] at [start], or null. Spaces and line
  /// breaks around the dots are allowed.
  int? _matchMember(int start, Rename rename) {
    var j = start + rename.segments.first.length;
    for (final segment in rename.segments.skip(1)) {
      while (j < s.length && _isSpace(s.codeUnitAt(j))) {
        j++;
      }
      if (_at(j) != 0x2E || _at(j + 1) == 0x2E) return null; // not `..`
      j++;
      while (j < s.length && _isSpace(s.codeUnitAt(j))) {
        j++;
      }
      if (!s.startsWith(segment, j)) return null;
      j += segment.length;
      if (_isIdentPart(_at(j))) return null;
    }
    if (rename.callOnly && !_isCallAt(j)) return null;
    return j;
  }

  /// Whether a call starts at [j]: `(`, or type arguments then `(`.
  bool _isCallAt(int j) {
    while (j < s.length && _isSpace(s.codeUnitAt(j))) {
      j++;
    }
    if (_at(j) == 0x3C) {
      var depth = 0;
      while (j < s.length) {
        final c = s.codeUnitAt(j);
        if (c == 0x3C) depth++;
        if (c == 0x3E) depth--;
        if (c == 0x3B || c == 0x7B || c == 0x7D) return false;
        j++;
        if (depth == 0) break;
      }
      while (j < s.length && _isSpace(s.codeUnitAt(j))) {
        j++;
      }
    }
    return _at(j) == 0x28;
  }
}
