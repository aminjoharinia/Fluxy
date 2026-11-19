/// Replaces each `%s` in [text] with the next of [args], in one pass:
/// inserted values are never scanned again (a value holding `%s` stays as it
/// is). Placeholders left over stay as `%s`; extra args are ignored.
String fillArgs(String text, List<String> args) {
  if (args.isEmpty) return text;
  final out = StringBuffer();
  var i = 0, next = 0;
  while (next < args.length) {
    final at = text.indexOf('%s', i);
    if (at < 0) break;
    out
      ..write(text.substring(i, at))
      ..write(args[next++]);
    i = at + 2;
  }
  out.write(text.substring(i));
  return out.toString();
}

/// Replaces `@name` placeholders in [text] with [params], in one pass.
///
/// A placeholder only matches a whole name (so `@admin` does not eat the
/// start of `@admin_email`; the longest matching name wins), and inserted
/// values are never scanned again (a value that contains `@other` stays as
/// it is). Names may contain `-`.
String fillParams(String text, Map<String, String> params) {
  if (params.isEmpty || !text.contains('@')) return text;
  final names = params.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final at = text.indexOf('@', i);
    if (at < 0) break;
    out.write(text.substring(i, at));
    String? matched;
    for (final name in names) {
      final end = at + 1 + name.length;
      if (text.startsWith(name, at + 1) &&
          (end == text.length || !_isNameChar(text.codeUnitAt(end)))) {
        matched = name;
        break;
      }
    }
    if (matched == null) {
      out.write('@');
      i = at + 1;
    } else {
      out.write(params[matched]);
      i = at + 1 + matched.length;
    }
  }
  out.write(text.substring(i));
  return out.toString();
}

/// ASCII letters, digits and `_`: characters that continue a placeholder name.
bool _isNameChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F; // _
