/// The rename map: `Old New` pairs read from `tool/renames.txt`.
library;

/// What an `Old` name matches.
enum RenameKind {
  /// A plain identifier, matched as a whole word (`GetxController`).
  word,

  /// A member access, `Target.member` (`Get.back`), matched as a whole word
  /// on each part; with a trailing `(` only where it is called.
  member,

  /// An import / export / part URI (`package:get/get.dart`); an `Old` ending
  /// in `/` rewrites every URI that starts with it.
  uri,
}

/// One `Old New` pair.
class Rename {
  Rename._(this.kind, this.from, this.to, {this.callOnly = false})
    : segments = kind == RenameKind.member ? from.split('.') : const [];

  final RenameKind kind;

  /// The old name, without a trailing `(`.
  final String from;

  /// The new name, without a trailing `(`.
  final String to;

  /// For a member pair written with a trailing `(`: only calls match.
  final bool callOnly;

  /// For a member pair: the parts of [from] (`['Get', 'back']`).
  final List<String> segments;

  @override
  String toString() => '$from -> $to';
}

/// A rename map that could not be read.
class RenameMapException implements Exception {
  RenameMapException(this.message);

  final String message;

  @override
  String toString() => message;
}

final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');
final _member = RegExp(
  r'^[A-Za-z_$][A-Za-z0-9_$]*(\.[A-Za-z_$][A-Za-z0-9_$]*)+$',
);

/// The parsed rename map.
class RenameMap {
  RenameMap(List<Rename> renames) {
    for (final r in renames) {
      switch (r.kind) {
        case RenameKind.word:
          words[r.from] = r;
        case RenameKind.member:
          (members[r.segments.first] ??= []).add(r);
        case RenameKind.uri:
          uris.add(r);
      }
    }
    // Longest first, so `Get.context.size` wins over `Get.context`.
    for (final list in members.values) {
      list.sort((a, b) => b.segments.length.compareTo(a.segments.length));
    }
  }

  /// Plain identifier pairs, by old name.
  final Map<String, Rename> words = {};

  /// Member pairs, by their first part.
  final Map<String, List<Rename>> members = {};

  /// URI pairs.
  final List<Rename> uris = [];

  bool get isEmpty => words.isEmpty && members.isEmpty && uris.isEmpty;

  int get length =>
      words.length +
      uris.length +
      members.values.fold(0, (n, l) => n + l.length);

  /// The rewritten URI, or null if no pair matches [uri].
  String? rewriteUri(String uri) {
    for (final r in uris) {
      if (r.from.endsWith('/')) {
        if (uri.startsWith(r.from)) return r.to + uri.substring(r.from.length);
      } else if (uri == r.from) {
        return r.to;
      }
    }
    return null;
  }

  /// Reads a map: one `Old New` pair per line, `#` starts a comment, blank
  /// lines are ignored. [source] names the file in error messages.
  static RenameMap parse(String text, {String source = 'map'}) {
    final renames = <Rename>[];
    final seen = <String, int>{};
    final lines = text.split('\n');
    for (var n = 0; n < lines.length; n++) {
      final where = '$source:${n + 1}';
      var line = lines[n];
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      line = line.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length != 2) {
        throw RenameMapException(
          '$where: expected "Old New", got ${parts.length} word(s): "$line"',
        );
      }
      final rename = _pair(parts[0], parts[1], where);
      final previous = seen[rename.from];
      if (previous != null) {
        throw RenameMapException(
          '$where: "${rename.from}" is already mapped on line $previous',
        );
      }
      seen[rename.from] = n + 1;
      renames.add(rename);
    }
    return RenameMap(renames);
  }

  static Rename _pair(String from, String to, String where) {
    if (from.contains(':') || from.contains('/')) {
      if (from.endsWith('/') != to.endsWith('/')) {
        throw RenameMapException(
          '$where: a URI prefix pair needs a trailing "/" on both sides',
        );
      }
      return Rename._(RenameKind.uri, from, to);
    }
    final callOnly = from.endsWith('(');
    if (callOnly != to.endsWith('(')) {
      throw RenameMapException(
        '$where: write the trailing "(" on both sides or on neither',
      );
    }
    if (callOnly) {
      from = from.substring(0, from.length - 1);
      to = to.substring(0, to.length - 1);
    }
    if (!_identifier.hasMatch(to) && !_member.hasMatch(to)) {
      throw RenameMapException('$where: "$to" is not a Dart name');
    }
    if (_member.hasMatch(from)) {
      return Rename._(RenameKind.member, from, to, callOnly: callOnly);
    }
    if (!_identifier.hasMatch(from)) {
      throw RenameMapException('$where: "$from" is not a Dart name');
    }
    if (callOnly) {
      throw RenameMapException(
        '$where: a trailing "(" is only for member pairs like "Get.back("',
      );
    }
    return Rename._(RenameKind.word, from, to);
  }
}
