/// The `migrate` command: applies a rename map to every Dart file of a
/// project, then formats the files it changed.
library;

import 'dart:io';

import 'cleanups.dart';
import 'rename_map.dart';
import 'rewriter.dart';

const usage = '''
Usage: dart run tool/migrate.dart <project-dir> [options]

Rewrites the Dart files of <project-dir> with the pairs of a rename map
(whole words; strings and comments are left alone, except names inside
string interpolation). Before that, it drops a refresh() that directly
follows a write that already notifies, turns deep package:get/<path>
imports into the whole library, and lists what to review: other refresh()
calls and strings that name an old GetX name.

Options:
  --map <file>       Rename map, one "Old New" pair per line, # comments.
                     Default: renames.txt next to migrate.dart.
  --dry-run          Report what would change, write nothing.
  --keep-refresh     Report redundant refresh() calls instead of dropping
                     them.
  --material-ui      Also rewrite package:flutter/material.dart to
                     package:material_ui/material_ui.dart and
                     package:flutter/cupertino.dart to
                     package:cupertino_ui/cupertino_ui.dart (add both
                     packages to pubspec.yaml; see the README).
  --format <mode>    After writing, run dart format on changed files:
                       auto    only files that were dart format clean before
                               (default; keeps unformatted code unformatted)
                       always  every changed file
                       never   none
  -h, --help         Show this help.''';

/// The pairs `--material-ui` adds to the map.
const materialUiPairs = '''

package:flutter/material.dart package:material_ui/material_ui.dart
package:flutter/cupertino.dart package:cupertino_ui/cupertino_ui.dart
''';

/// When to run `dart format` on changed files.
enum FormatMode { auto, always, never }

/// Directories never scanned (`actions-runner`: a self-hosted GitHub runner
/// kept in the app folder holds another checkout of the app).
const _skippedDirs = {'build', 'node_modules', 'Pods', 'actions-runner'};

/// Files that declare the old names on purpose (Fluxy's deprecated aliases).
const _skippedFiles = {'deprecated_names.dart'};

/// Runs the command; returns the exit code (64 for a usage error, 65 for a
/// bad map, 1 if dart format failed).
Future<int> runMigrate(
  List<String> args, {
  required String defaultMapPath,
  StringSink? log,
  String? dartExecutable,
}) async {
  final sink = log ?? stdout;
  try {
    return await _run(args, defaultMapPath, sink, dartExecutable);
  } on _UsageException catch (e) {
    return _usageError(sink, e.message);
  }
}

Future<int> _run(
  List<String> args,
  String defaultMapPath,
  StringSink sink,
  String? dartExecutable,
) async {
  String? project;
  String mapPath = defaultMapPath;
  var dryRun = false;
  var keepRefresh = false;
  var materialUi = false;
  var format = FormatMode.auto;
  for (var n = 0; n < args.length; n++) {
    final arg = args[n];
    String value() {
      if (n + 1 >= args.length) throw _UsageException('$arg needs a value');
      return args[++n];
    }

    if (arg == '-h' || arg == '--help') {
      sink.writeln(usage);
      return 0;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--keep-refresh') {
      keepRefresh = true;
    } else if (arg == '--material-ui') {
      materialUi = true;
    } else if (arg == '--map') {
      mapPath = value();
    } else if (arg.startsWith('--map=')) {
      mapPath = arg.substring('--map='.length);
    } else if (arg == '--format' || arg.startsWith('--format=')) {
      final name = arg == '--format' ? value() : arg.substring(9);
      format = FormatMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => throw _UsageException('unknown --format "$name"'),
      );
    } else if (arg.startsWith('-')) {
      return _usageError(sink, 'unknown option "$arg"');
    } else if (project == null) {
      project = arg;
    } else {
      return _usageError(sink, 'only one <project-dir> is allowed');
    }
  }
  if (project == null) return _usageError(sink, 'missing <project-dir>');

  final root = Directory(project);
  if (!root.existsSync()) return _usageError(sink, 'no directory "$project"');
  final mapFile = File(mapPath);
  if (!mapFile.existsSync()) return _usageError(sink, 'no map "$mapPath"');

  final RenameMap map;
  try {
    map = RenameMap.parse(
      mapFile.readAsStringSync() + (materialUi ? materialUiPairs : ''),
      source: mapPath,
    );
  } on RenameMapException catch (e) {
    sink.writeln('error: $e');
    return 65;
  }
  if (map.isEmpty) {
    sink.writeln('No renames in $mapPath (every line is a comment).');
    return 0;
  }

  final rootPath = root.absolute.path;
  final changed = <String, RewriteResult>{}; // relative path -> result
  final review = <String>[];
  for (final file in dartFiles(root)) {
    final path = _relative(file.absolute.path, rootPath);
    final source = file.readAsStringSync();
    final cleaned = cleanup(source, dropRefresh: !keepRefresh, map: map);
    final result = rewrite(cleaned.source, map);
    final changes = cleaned.changes + result.changes;
    if (changes > 0) changed[path] = RewriteResult(result.source, changes);
    for (final note in cleaned.notes) {
      review.add('$path:$note');
    }
  }

  final paths = changed.keys.toList()..sort();
  for (final path in paths) {
    sink.writeln('$path: ${changed[path]!.changes}');
  }
  final total = changed.values.fold(0, (n, r) => n + r.changes);
  if (review.isNotEmpty) {
    sink.writeln('Review (${review.length}):');
    for (final line in review) {
      sink.writeln('  $line');
    }
  }
  final summary =
      '$total change(s) in ${paths.length} file(s) '
      '(${map.length} rename(s) in the map)';
  if (dryRun || paths.isEmpty) {
    sink.writeln(dryRun ? '$summary, dry run: nothing written.' : summary);
    return 0;
  }

  final dart = dartExecutable ?? Platform.resolvedExecutable;
  var toFormat = <String>[];
  if (format == FormatMode.always) {
    toFormat = paths;
  } else if (format == FormatMode.auto) {
    final unclean = await _notFormatted(dart, rootPath, paths);
    toFormat = [
      for (final p in paths)
        if (!unclean.contains(p)) p,
    ];
  }

  for (final path in paths) {
    File('$rootPath/$path').writeAsStringSync(changed[path]!.source);
  }
  sink.writeln(summary);

  if (toFormat.isNotEmpty) {
    final result = await Process.run(dart, [
      'format',
      ...toFormat,
    ], workingDirectory: rootPath);
    if (result.exitCode != 0) {
      sink.writeln(
        'dart format failed (exit ${result.exitCode}):\n'
        '${result.stdout}${result.stderr}',
      );
      return 1;
    }
    sink.writeln('Formatted ${toFormat.length} file(s).');
  }
  final skipped = paths.length - toFormat.length;
  if (skipped > 0 && format == FormatMode.auto) {
    sink.writeln(
      'Not formatted ($skipped): not dart format clean before the '
      'rewrite; use --format always to format them anyway.',
    );
  }
  return 0;
}

/// The Dart files under [root], skipping hidden folders (`.dart_tool`,
/// `.git`, `.symlinks`, ...), `build`, `node_modules`, `Pods` and
/// `actions-runner`, and
/// `deprecated_names.dart` files (they declare the old names on purpose).
Iterable<File> dartFiles(Directory root) sync* {
  final entries = root.listSync(followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entry in entries) {
    final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (entry is Directory) {
      if (name.startsWith('.') || _skippedDirs.contains(name)) continue;
      yield* dartFiles(entry);
    } else if (entry is File &&
        name.endsWith('.dart') &&
        !_skippedFiles.contains(name)) {
      yield entry;
    }
  }
}

/// The [paths] that `dart format` would change, as they are on disk now.
Future<Set<String>> _notFormatted(
  String dart,
  String root,
  List<String> paths,
) async {
  final result = await Process.run(dart, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...paths,
  ], workingDirectory: root);
  if (result.exitCode == 0) return {};
  if (result.exitCode != 1) return paths.toSet(); // could not format at all
  final unclean = <String>{};
  for (final line in (result.stdout as String).split('\n')) {
    if (line.startsWith('Changed ')) unclean.add(line.substring(8).trim());
  }
  return unclean;
}

String _relative(String path, String root) {
  final prefix = root.endsWith('/') ? root : '$root/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

int _usageError(StringSink sink, String message) {
  sink
    ..writeln('error: $message')
    ..writeln()
    ..writeln(usage);
  return 64;
}

class _UsageException implements Exception {
  _UsageException(this.message);

  final String message;
}
