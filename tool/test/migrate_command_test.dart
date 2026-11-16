import 'dart:io';

import 'package:test/test.dart';

import '../src/migrate_command.dart';

void main() {
  late Directory project;
  late Directory mapDir;
  late File map;
  late StringBuffer log;

  void write(String path, String content) {
    File('${project.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String read(String path) => File('${project.path}/$path').readAsStringSync();

  Future<int> run(List<String> args) =>
      runMigrate(args, defaultMapPath: map.path, log: log);

  const formatted = '''
import 'package:get/get.dart';

class A extends GetxController {
  GetStatus<int> status = GetStatus<int>.loading();
}
''';

  // Valid Dart that dart format would change.
  const unformatted = '''
import 'package:get/get.dart';
class B extends GetxController {
    GetStatus<int>?   s;
}
''';

  setUp(() {
    project = Directory.systemTemp.createTempSync('migrate_test_');
    mapDir = Directory.systemTemp.createTempSync('migrate_map_');
    map = File('${mapDir.path}/renames.txt')
      ..writeAsStringSync(
        'GetxController FluxController\nGetStatus AsyncStatus\n',
      );
    log = StringBuffer();
    write('lib/a.dart', formatted);
    write('lib/sub/b.dart', unformatted);
    write('lib/none.dart', 'class C {}\n');
    write('test/c_test.dart', 'final x = GetStatus<int>.empty();\n');
    write('.dart_tool/gen.dart', 'GetxController x;\n');
    write('build/out.dart', 'GetxController x;\n');
    write('ios/.symlinks/p.dart', 'GetxController x;\n');
    write('lib/readme.txt', 'GetxController\n');
    write('lib/deprecated_names.dart', 'typedef GetxController = X;\n');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
    mapDir.deleteSync(recursive: true);
  });

  test('dry run reports per-file counts and writes nothing', () async {
    expect(await run([project.path, '--dry-run']), 0);
    expect(log.toString().split('\n').where((l) => l.isNotEmpty).toList(), [
      'lib/a.dart: 3',
      'lib/sub/b.dart: 2',
      'test/c_test.dart: 1',
      '6 change(s) in 3 file(s) (2 rename(s) in the map), dry run: nothing written.',
    ]);
    expect(read('lib/a.dart'), formatted);
  });

  test(
    'apply rewrites, skips hidden / build folders and non-Dart files',
    () async {
      expect(await run([project.path, '--format', 'never']), 0);
      expect(read('lib/a.dart'), contains('class A extends FluxController'));
      expect(read('test/c_test.dart'), 'final x = AsyncStatus<int>.empty();\n');
      expect(read('.dart_tool/gen.dart'), 'GetxController x;\n');
      expect(read('build/out.dart'), 'GetxController x;\n');
      expect(read('ios/.symlinks/p.dart'), 'GetxController x;\n');
      expect(read('lib/readme.txt'), 'GetxController\n');
      expect(
        read('lib/deprecated_names.dart'),
        'typedef GetxController = X;\n',
      );
      expect(read('lib/none.dart'), 'class C {}\n');
      // --format never: the unformatted file keeps its layout.
      expect(read('lib/sub/b.dart'), contains('    AsyncStatus<int>?   s;'));
    },
  );

  test('--format auto formats only files that were clean before', () async {
    // A rename that makes a line longer than 80 columns in a clean file.
    write('lib/long.dart', '''
void f() {
  final aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = GetStatus<int>.loading();
}
''');
    expect(await run([project.path]), 0);
    expect(read('lib/long.dart'), '''
void f() {
  final aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa =
      AsyncStatus<int>.loading();
}
''');
    expect(read('lib/sub/b.dart'), contains('    AsyncStatus<int>?   s;'));
    expect(log.toString(), contains('Not formatted (1)'));
  });

  test('--format always formats every changed file', () async {
    expect(await run([project.path, '--format=always']), 0);
    expect(read('lib/sub/b.dart'), contains('\n  AsyncStatus<int>? s;\n'));
  });

  test(
    '--map selects another map; an all-comment map changes nothing',
    () async {
      final other = File('${project.path}/empty.txt')
        ..writeAsStringSync('# GetxController FluxController\n');
      expect(await run([project.path, '--map', other.path]), 0);
      expect(log.toString(), contains('No renames'));
      expect(read('lib/a.dart'), formatted);
    },
  );

  test('usage and map errors', () async {
    expect(await run([]), 64);
    expect(await run([project.path, '--bogus']), 64);
    expect(await run([project.path, '--format', 'sometimes']), 64);
    expect(await run([project.path, '--map']), 64);
    expect(await run(['${project.path}/missing']), 64);
    final bad = File('${project.path}/bad.txt')..writeAsStringSync('A B C\n');
    expect(await run([project.path, '--map=${bad.path}']), 65);
    expect(log.toString(), contains('bad.txt:1:'));
  });

  test('the shipped renames.txt parses and rewrites get imports', () async {
    write('lib/c.dart', "import 'package:get/state_manager.dart';\n");
    final shipped = File('renames.txt');
    expect(
      await run([project.path, '--map', shipped.path, '--format', 'never']),
      0,
    );
    expect(read('lib/c.dart'), "import 'package:fluxy/state_manager.dart';\n");
    expect(
      read('lib/a.dart'),
      startsWith("import 'package:fluxy/fluxy.dart';"),
    );
  });
}
