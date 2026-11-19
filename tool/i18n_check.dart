/// Lists translation keys used in code but missing from a dictionary, and
/// dictionary keys no code uses; see `--help` and `tool/README.md`.
///
///     dart run tool/i18n_check.dart <project-dir> [--locale en_US] [--fail]
library;

import 'dart:io';

import 'src/i18n_check_command.dart';

Future<void> main(List<String> args) async {
  exitCode = await runI18nCheck(args);
}
