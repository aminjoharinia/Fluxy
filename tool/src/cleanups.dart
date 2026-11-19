/// Clean-ups for apps moving from GetX, run before the renames:
///
/// * a `x.refresh();` statement right after a write to `x` that always
///   notifies (`x[i] = v`, `x.add(...)`, `x.removeWhere(...)` ...) is
///   dropped; every other `refresh()` statement is reported for review;
/// * a deep `package:get/<path>` import (no such library in Fluxy) becomes
///   `package:get/get.dart`, and is dropped when the file already has it;
/// * string literals that name an old GetX name are reported (not changed).
///
/// Like the rewriter, a scanner rather than a parser: comments and strings
/// are masked out first, then the code is matched with patterns.
library;

import 'rename_map.dart';

/// Something a person should look at: [line] is 1-based.
class Note {
  Note(this.line, this.message);

  final int line;
  final String message;

  @override
  String toString() => '$line: $message';
}

/// The cleaned source, how many edits were made, and what to review.
class CleanupResult {
  CleanupResult(this.source, this.changes, this.notes);

  final String source;
  final int changes;
  final List<Note> notes;
}

/// Writes that always notify on `RxList` / `RxMap` / `RxSet`, so a
/// `refresh()` right after one is redundant. Left out on purpose, because
/// they may not notify: `.value =` (an identical value), `assignAll` (on a
/// map, the same map), `putIfAbsent`, `addIf` / `addAllIf`, `assign`.
const notifyingMethods = {
  'add', 'addAll', 'addEntries', 'insert', 'insertAll', //
  'remove', 'removeAt', 'removeLast', 'removeRange', 'removeWhere',
  'retainWhere', 'clear', 'setAll', 'setRange', 'replaceRange', 'fillRange',
  'sort', 'shuffle', 'update', 'updateAll',
};

/// Top-level GetX libraries that Fluxy also has (`package:fluxy/<name>`).
const fluxyLibraries = {
  'get.dart',
  'state_manager.dart',
  'route_manager.dart',
  'instance_manager.dart',
  'utils.dart',
};

/// Runs the clean-ups on [source]. With [dropRefresh] false, redundant
/// `refresh()` calls are reported instead of dropped. [map] gives the old
/// names looked for in strings (none when null).
CleanupResult cleanup(
  String source, {
  bool dropRefresh = true,
  RenameMap? map,
}) {
  final notes = <Note>[];
  var changes = 0;
  var s = source;

  // Refresh first: imports sit above any code, so the lines reported by
  // both passes are the lines of the original file.
  final refresh = _refreshCalls(s, notes, drop: dropRefresh);
  s = refresh.source;
  changes += refresh.changes;

  final imports = _deepImports(s, notes);
  s = imports.source;
  changes += imports.changes;

  // Strings are reported against the original file, so lines match the
  // file the person opens (before any line was dropped).
  if (map != null) notes.addAll(_oldNamesInStrings(source, map));
  notes.sort((a, b) => a.line.compareTo(b.line));
  return CleanupResult(s, changes, notes);
}

int _lineOf(String s, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < s.length; i++) {
    if (s.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

// ---------------------------------------------------------------- masking

/// [source] with comments and string literals (interpolations included)
/// replaced by spaces, line breaks kept, so offsets still match. [strings]
/// receives the ranges of string literal bodies (without quotes), outermost
/// literals only.
String mask(String source, [List<(int, int)>? strings]) {
  final out = source.codeUnits.toList();
  void blank(int from, int to) {
    for (var k = from; k < to && k < out.length; k++) {
      if (out[k] != 0x0A) out[k] = 0x20;
    }
  }

  var i = 0;
  while (i < source.length) {
    final end = _skipNonCode(source, i);
    if (end != null) {
      final isString = source.codeUnitAt(i) != 0x2F;
      if (isString && strings != null) strings.add((i, end));
      blank(i, end);
      i = end;
    } else {
      i++;
    }
  }
  return String.fromCharCodes(out);
}

/// If a comment or string literal starts at [i], the offset just after it.
int? _skipNonCode(String s, int i) {
  final c = s.codeUnitAt(i);
  final next = i + 1 < s.length ? s.codeUnitAt(i + 1) : -1;
  if (c == 0x2F && next == 0x2F) {
    final end = s.indexOf('\n', i);
    return end < 0 ? s.length : end;
  }
  if (c == 0x2F && next == 0x2A) {
    var depth = 0;
    var j = i;
    while (j < s.length) {
      if (s.startsWith('/*', j)) {
        depth++;
        j += 2;
      } else if (s.startsWith('*/', j)) {
        depth--;
        j += 2;
        if (depth == 0) return j;
      } else {
        j++;
      }
    }
    return s.length;
  }
  if (c == 0x27 || c == 0x22) return _skipString(s, i, raw: false);
  if (c == 0x72 && (next == 0x27 || next == 0x22)) {
    final before = i > 0 ? s.codeUnitAt(i - 1) : -1;
    if (!_isIdentPart(before)) return _skipString(s, i + 1, raw: true);
  }
  return null;
}

int _skipString(String s, int i, {required bool raw}) {
  final quote = s[i];
  final triple = s.startsWith(quote * 3, i);
  final delimiter = triple ? quote * 3 : quote;
  var j = i + delimiter.length;
  while (j < s.length) {
    if (s.startsWith(delimiter, j)) return j + delimiter.length;
    final c = s.codeUnitAt(j);
    if (!triple && c == 0x0A) return j; // unterminated
    if (!raw && c == 0x5C) {
      j += 2;
      continue;
    }
    if (!raw && c == 0x24 && j + 1 < s.length && s.codeUnitAt(j + 1) == 0x7B) {
      // `${ ... }`: code, possibly with strings and braces of its own.
      j += 2;
      var depth = 0;
      while (j < s.length) {
        final skipped = _skipNonCode(s, j);
        if (skipped != null) {
          j = skipped;
          continue;
        }
        final d = s.codeUnitAt(j);
        if (d == 0x7B) depth++;
        if (d == 0x7D) {
          if (depth == 0) break;
          depth--;
        }
        j++;
      }
      j++;
      continue;
    }
    j++;
  }
  return s.length;
}

bool _isIdentPart(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x30 && c <= 0x39) ||
    c == 0x5F ||
    c == 0x24;

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

// ------------------------------------------------------------ edits

class _Edit {
  _Edit(this.from, this.to, this.text);
  final int from;
  final int to;
  final String text;
}

String _apply(String s, List<_Edit> edits) {
  edits.sort((a, b) => b.from.compareTo(a.from));
  var out = s;
  for (final e in edits) {
    out = out.replaceRange(e.from, e.to, e.text);
  }
  return out;
}

/// The range that removes the statement [from]..[to]: its whole line when
/// nothing else (code or comment) is on it, else the statement and the
/// spaces before it.
(int, int) _statementRange(String s, int from, int to) {
  var lineStart = from;
  while (lineStart > 0 && s.codeUnitAt(lineStart - 1) != 0x0A) {
    lineStart--;
  }
  var lineEnd = to;
  while (lineEnd < s.length && s.codeUnitAt(lineEnd) != 0x0A) {
    lineEnd++;
  }
  final before = s.substring(lineStart, from).trim();
  final after = s.substring(to, lineEnd).trim();
  if (before.isEmpty && after.isEmpty) {
    return (lineStart, lineEnd < s.length ? lineEnd + 1 : lineEnd);
  }
  if (before.isEmpty) {
    // A comment follows on the line: keep the indent, drop the gap.
    var end = to;
    while (end < lineEnd && s.codeUnitAt(end) == 0x20) {
      end++;
    }
    return (from, end);
  }
  var start = from;
  while (start > lineStart && s.codeUnitAt(start - 1) == 0x20) {
    start--;
  }
  return (start, to);
}

// --------------------------------------------------------- deep imports

final _directive = RegExp(
  r'''(import|export)\s+(['"])package:get/([^'"\s]+)\2([^;]*);''',
);
final _plainGetImport = RegExp(
  r'''import\s+(['"])package:(get/get|fluxy/fluxy)\.dart\1\s*;''',
);

CleanupResult _deepImports(String s, List<Note> notes) {
  final masked = mask(s);
  // A plain import of the whole library already in the file (code only).
  var hasPlain = _plainGetImport
      .allMatches(s)
      .any((m) => masked.codeUnitAt(m.start) == 0x69);
  final edits = <_Edit>[];
  for (final m in _directive.allMatches(s)) {
    if (masked.codeUnitAt(m.start) == 0x20) continue; // in a comment / string
    final path = m.group(3)!;
    if (fluxyLibraries.contains(path)) continue;
    final keyword = m.group(1)!;
    final quote = m.group(2)!;
    final clauses = m.group(4)!;
    final line = _lineOf(s, m.start);
    if (keyword == 'import' && clauses.trim().isEmpty && hasPlain) {
      final (from, to) = _statementRange(s, m.start, m.end);
      edits.add(_Edit(from, to, ''));
      notes.add(Note(line, 'dropped package:get/$path (the file already '
          'imports the whole library)'));
      continue;
    }
    edits.add(_Edit(m.start, m.end,
        '$keyword ${quote}package:get/get.dart$quote$clauses;'));
    notes.add(Note(line, 'package:get/$path → the whole library '
        '(Fluxy has no such file)'));
    if (keyword == 'import' && clauses.trim().isEmpty) hasPlain = true;
  }
  return CleanupResult(_apply(s, edits), edits.length, const []);
}

// -------------------------------------------------------------- refresh

final _refreshStatement = RegExp(
  r'([A-Za-z_$][\w$]*(?:\s*\.\s*[A-Za-z_$][\w$]*)*)\s*\.\s*refresh\s*\(\s*\)\s*;',
);

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

CleanupResult _refreshCalls(String s, List<Note> notes, {required bool drop}) {
  final masked = mask(s);
  final edits = <_Edit>[];
  for (final m in _refreshStatement.allMatches(masked)) {
    final start = m.start;
    // A statement of its own: after `;`, `{` or `}` (or the file start).
    var p = start - 1;
    while (p >= 0 && _isSpace(masked.codeUnitAt(p))) {
      p--;
    }
    final boundary = p < 0 ? 0x3B : masked.codeUnitAt(p);
    if (boundary != 0x3B && boundary != 0x7B && boundary != 0x7D) continue;
    final receiver = _squash(m.group(1)!);
    if (receiver == 'this' || receiver.endsWith('.this')) continue;
    final line = _lineOf(s, start);
    final method =
        boundary == 0x3B && p >= 0 ? _earlierWrite(masked, p, receiver) : null;
    if (method == null) {
      notes.add(Note(line, '$receiver.refresh() kept: review it (it does not '
          'directly follow a write to $receiver that always notifies; '
          'refresh() is @protected in Fluxy)'));
      continue;
    }
    if (!drop) {
      notes.add(Note(line, '$receiver.refresh() is redundant after '
          '$receiver$method (kept: --keep-refresh)'));
      continue;
    }
    final (from, to) = _statementRange(s, start, m.end);
    edits.add(_Edit(from, to, ''));
  }
  return CleanupResult(_apply(s, edits), edits.length, const []);
}

/// How many statements back a write may be, past statements that save the
/// receiver (`await db.write(key, list.toList());`).
const maxLookBack = 5;

/// Walks back from the statement ending at [semicolon] (in the same block)
/// to a write to [receiver] that always notifies, passing only statements
/// that read [receiver] (saving it) and write nothing: no assignment, no
/// `++` / `--`, no call to a notifying method on anything. A statement that
/// does not mention [receiver] stops the walk: any call could edit a row in
/// place. Returns the write's form, or null.
String? _earlierWrite(String masked, int semicolon, String receiver) {
  var end = semicolon;
  for (var n = 0; n < maxLookBack; n++) {
    final (statement, start) = _statementEndingAt(masked, end);
    final write = _notifyingWrite(statement, receiver);
    if (write != null) return write;
    if (_writes(statement) || !_mentions(statement, receiver)) return null;
    // The `;` that ends the statement before, or stop at a block edge.
    var p = start - 1;
    while (p >= 0 && _isSpace(masked.codeUnitAt(p))) {
      p--;
    }
    if (p < 0 || masked.codeUnitAt(p) != 0x3B) return null;
    end = p;
  }
  return null;
}

final _assignment = RegExp(r'(^|[^=!<>])=(?![=>])|\+\+|--');
final _notifyingCall = RegExp(
  r'\.\s*(' + notifyingMethods.join('|') + r')\s*(<[^;]*?>)?\s*\(',
);

/// Whether [statement] reads [receiver] (spaces around dots allowed).
bool _mentions(String statement, String receiver) => RegExp(
      r'(^|[^\w$.])' +
          receiver.split('.').map(RegExp.escape).join(r'\s*\.\s*') +
          r'(?![\w$])',
    ).hasMatch(statement);

/// Whether [statement] may write something (see [_earlierWrite]).
bool _writes(String statement) =>
    _assignment.hasMatch(statement) || _notifyingCall.hasMatch(statement);

/// The statement that ends with the `;` at [semicolon] (as masked code,
/// trimmed) and the offset where its text starts.
(String, int) _statementEndingAt(String masked, int semicolon) {
  var q = semicolon - 1;
  var depth = 0;
  while (q >= 0) {
    final c = masked.codeUnitAt(q);
    if (depth == 0 && (c == 0x3B || c == 0x7D)) break; // `;` or a block's `}`
    if (c == 0x29 || c == 0x5D || c == 0x7D) depth++;
    if (c == 0x28 || c == 0x5B || c == 0x7B) {
      if (depth == 0) break;
      depth--;
    }
    q--;
  }
  var start = q + 1;
  while (start < semicolon && _isSpace(masked.codeUnitAt(start))) {
    start++;
  }
  return (masked.substring(start, semicolon).trim(), start);
}

/// How [statement] writes to [receiver] (`[…] =` or `.add(` …) when it is
/// a write that always notifies, else null.
String? _notifyingWrite(String statement, String receiver) {
  final s = statement;
  // Match the receiver, allowing spaces around its dots.
  var i = 0;
  var r = 0;
  while (r < receiver.length) {
    while (i < s.length && _isSpace(s.codeUnitAt(i))) {
      i++;
    }
    if (i >= s.length || s[i] != receiver[r]) return null;
    i++;
    r++;
  }
  if (i < s.length && _isIdentPart(s.codeUnitAt(i))) return null;
  while (i < s.length && _isSpace(s.codeUnitAt(i))) {
    i++;
  }
  if (i >= s.length) return null;
  if (s[i] == '[') {
    var depth = 0;
    var j = i;
    for (; j < s.length; j++) {
      if (s[j] == '[') depth++;
      if (s[j] == ']' && --depth == 0) break;
    }
    final rest = s.substring(j + 1).trimLeft();
    final op = RegExp(r'^(\?\?|[-+*/%~^|&]|<<|>>>?|~/)?=(?!=)').firstMatch(rest);
    return op == null ? null : '[…] ${op.group(0)}';
  }
  if (s[i] != '.') return null;
  final call = RegExp(r'^\.\s*([A-Za-z_$][\w$]*)\s*(<[^;]*?>)?\s*\(')
      .firstMatch(s.substring(i));
  if (call == null || !notifyingMethods.contains(call.group(1))) return null;
  return '.${call.group(1)}(…)';
}

// -------------------------------------------------------------- strings

/// Old names in string literals: a test that greps the app's source, a log
/// line. Plain `Get` only counts when followed by a dot (`Get.put`), since
/// "Get started" is just English.
List<Note> _oldNamesInStrings(String s, RenameMap map) {
  final strings = <(int, int)>[];
  mask(s, strings);
  final notes = <Note>[];
  final word = RegExp(r'[A-Za-z_$][\w$]*');
  for (final (from, to) in strings) {
    if (_isDirectiveUri(s, from)) continue;
    // Interpolated code is renamed by the rewriter, so only literal text.
    final text = s
        .substring(from, to)
        .replaceAll(RegExp(r'\$\{[^}]*\}'), ' ')
        .replaceAll(RegExp(r'\$[A-Za-z_][\w]*'), ' ');
    final found = <String>{};
    for (final m in word.allMatches(text)) {
      final name = m.group(0)!;
      final before = m.start > 0 ? text.codeUnitAt(m.start - 1) : -1;
      if (_isIdentPart(before)) continue;
      if (!map.words.containsKey(name)) continue;
      if (name == 'Get' && (m.end >= text.length || text[m.end] != '.')) {
        continue;
      }
      found.add(name);
    }
    if (text.contains('package:get/')) found.add('package:get/');
    if (found.isEmpty) continue;
    notes.add(Note(_lineOf(s, from), 'a string names ${found.join(', ')} '
        '(not changed: check whether it should use the new name)'));
  }
  return notes;
}

/// Whether the string at [from] is the URI of an import / export / part.
bool _isDirectiveUri(String s, int from) {
  var p = from - 1;
  while (p >= 0 && _isSpace(s.codeUnitAt(p))) {
    p--;
  }
  final end = p + 1;
  while (p >= 0 && _isIdentPart(s.codeUnitAt(p))) {
    p--;
  }
  final keyword = s.substring(p + 1, end);
  return keyword == 'import' || keyword == 'export' || keyword == 'part' ||
      keyword == 'of';
}
