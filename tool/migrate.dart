/// Applies a rename map to a project's Dart files; see `--help` and
/// `tool/README.md`.
///
///     dart run tool/migrate.dart <project-dir> [--map tool/renames.txt] [--dry-run]
library;

import 'dart:io';

import 'src/migrate_command.dart';

Future<void> main(List<String> args) async {
  final here = File.fromUri(Platform.script).parent.path;
  exitCode = await runMigrate(args, defaultMapPath: '$here/renames.txt');
}
