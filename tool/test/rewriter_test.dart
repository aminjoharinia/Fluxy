import 'package:test/test.dart';

import '../src/rename_map.dart';
import '../src/rewriter.dart';

String apply(String map, String source) =>
    rewrite(source, RenameMap.parse(map)).source;

int count(String map, String source) =>
    rewrite(source, RenameMap.parse(map)).changes;

const types = '''
GetxController FluxController
GetStatus AsyncStatus
''';

void main() {
  group('words', () {
    test('renames whole words in code', () {
      expect(
        apply(
          types,
          'class A extends GetxController {\n  GetStatus<int>? s;\n}',
        ),
        'class A extends FluxController {\n  AsyncStatus<int>? s;\n}',
      );
    });

    test('leaves longer names alone', () {
      const source =
          'GetxControllerX a; MyGetxController b; GetStatus2 c; _GetStatus d;';
      expect(apply(types, source), source);
    });

    test('renames generic uses, constructors, is-checks and bounds', () {
      expect(
        apply(
          types,
          'final s = GetStatus<int>.loading(); o is GetStatus; T f<T extends GetxController>() {}',
        ),
        'final s = AsyncStatus<int>.loading(); o is AsyncStatus; T f<T extends FluxController>() {}',
      );
    });

    test('renames after an import prefix', () {
      expect(apply(types, 'get.GetxController c;'), 'get.FluxController c;');
    });

    test('renames in show / hide combinators', () {
      expect(
        apply(
          types,
          "import 'package:get/get.dart' show GetxController, GetStatus;",
        ),
        "import 'package:get/get.dart' show FluxController, AsyncStatus;",
      );
    });

    test('does not rename subclasses that keep their names', () {
      const source = 'LoadingStatus() SuccessStatus(:final data)';
      expect(apply(types, source), source);
    });

    test('one pass: a new name is not renamed again', () {
      expect(apply('A B\nB C', 'A B'), 'B C');
    });

    test('counts every replacement', () {
      expect(
        count(types, 'GetxController GetStatus GetStatus // GetStatus'),
        3,
      );
    });
  });

  group('comments', () {
    test('line and doc comments are left alone', () {
      const source = '// GetxController\n/// See [GetStatus].\nGetStatus s;';
      expect(
        apply(types, source),
        '// GetxController\n/// See [GetStatus].\nAsyncStatus s;',
      );
    });

    test('nested block comments are left alone', () {
      const source = '/* GetStatus /* GetStatus */ GetStatus */ GetStatus';
      expect(
        apply(types, source),
        '/* GetStatus /* GetStatus */ GetStatus */ AsyncStatus',
      );
    });

    test('a slash that is not a comment is code', () {
      expect(apply(types, 'a / GetStatus.x'), 'a / AsyncStatus.x');
    });
  });

  group('strings', () {
    test('plain, double and triple quoted strings are left alone', () {
      const source = '''
var a = 'GetStatus';
var b = "GetStatus";
var c = \'\'\'
GetStatus 'quoted' GetStatus
\'\'\';
var d = """GetStatus""";
GetStatus e;''';
      final out = apply(types, source);
      expect(out, source.replaceFirst('GetStatus e;', 'AsyncStatus e;'));
    });

    test('raw strings are left alone, interpolation included', () {
      const source = r"var a = r'$GetStatus ${GetStatus}'; var b = r'\';";
      expect(apply(types, source), source);
    });

    test('escaped quotes and dollars do not end or start anything', () {
      const source = r"var a = 'it\'s GetStatus \$GetStatus'; GetStatus b;";
      expect(
        apply(types, source),
        r"var a = 'it\'s GetStatus \$GetStatus'; AsyncStatus b;",
      );
    });

    test('names inside interpolation are code', () {
      expect(
        apply(types, r"print('${GetStatus<int>.loading()} and $GetStatus');"),
        r"print('${AsyncStatus<int>.loading()} and $AsyncStatus');",
      );
    });

    test('nested strings and braces inside interpolation', () {
      expect(
        apply(types, r"""f('${{'k': "GetStatus"}[GetStatus]} GetStatus');"""),
        r"""f('${{'k': "GetStatus"}[AsyncStatus]} GetStatus');""",
      );
    });

    test(r'simple interpolation stops at $ and non-identifier characters', () {
      expect(
        apply(types, r"'$GetStatus$GetStatus.x'"),
        r"'$AsyncStatus$AsyncStatus.x'",
      );
    });
  });

  group('members', () {
    const nav = 'Get.back Nav.back\nGet.to( Nav.to(';

    test('rewrites member access, call or not', () {
      expect(
        apply(nav, 'Get.back(); onTap: Get.back,'),
        'Nav.back(); onTap: Nav.back,',
      );
    });

    test('allows spaces and line breaks around the dot', () {
      expect(
        apply(nav, 'Get . back(); Get\n      .back();'),
        'Nav.back(); Nav.back();',
      );
    });

    test('whole words on both sides', () {
      const source = 'Get.backX(); MyGet.back(); Getter.back();';
      expect(apply(nav, source), source);
    });

    test('not when Get is itself a member', () {
      const source = 'foo.Get.back(); foo?.Get.back();';
      expect(apply(nav, source), source);
    });

    test('a comment ending with a dot does not count as a dot', () {
      expect(
        apply(nav, '// back on the list.\nGet.back();\n/* x. */ Get.back();'),
        '// back on the list.\nNav.back();\n/* x. */ Nav.back();',
      );
    });

    test('not on a cascade', () {
      const source = 'Get..back();';
      expect(apply(nav, source), source);
    });

    test('a trailing ( matches calls only, with type arguments', () {
      expect(
        apply(
          nav,
          'Get.to(Page()); Get.to<Map<String, int>>(Page()); f(Get.to);',
        ),
        'Nav.to(Page()); Nav.to<Map<String, int>>(Page()); f(Get.to);',
      );
    });

    test('longest member pair wins, words still apply to the rest', () {
      const map =
          'Get Fluxy\nGet.context.size Screen.size\nGet.context Nav.context';
      expect(
        apply(map, 'Get.context.size; Get.context; Get.put(x);'),
        'Screen.size; Nav.context; Fluxy.put(x);',
      );
    });

    test('member to a top-level function', () {
      expect(apply('Get.batch batch', 'Get.batch(() {});'), 'batch(() {});');
    });

    test('left alone in strings and comments', () {
      const source = "// Get.back()\nvar s = 'Get.back()';";
      expect(apply(nav, source), source);
    });
  });

  group('URIs', () {
    const uri = 'package:get/get.dart package:fluxy/fluxy.dart';

    test('rewrites import and export directives', () {
      expect(
        apply(
          uri,
          "import 'package:get/get.dart';\nexport \"package:get/get.dart\" show Get;",
        ),
        "import 'package:fluxy/fluxy.dart';\nexport \"package:fluxy/fluxy.dart\" show Get;",
      );
    });

    test(
      'rewrites after comments, other directives and conditional imports',
      () {
        const source = '''
// header
library;

import 'dart:io';
import 'other.dart' if (dart.library.io) 'package:get/get.dart';
import 'package:get/get.dart' as get;
''';
        expect(
          apply(uri, source),
          source.replaceAll('package:get/get.dart', 'package:fluxy/fluxy.dart'),
        );
      },
    );

    test('leaves other URIs and strings in code alone', () {
      const source = '''
import 'package:get/get_utils.dart';
void main() {
  final s = 'package:get/get.dart';
}
''';
      expect(apply(uri, source), source);
    });

    test('a prefix pair rewrites every URI under it', () {
      const map = 'package:get/ package:fluxy/';
      expect(
        apply(
          map,
          "import 'package:get/get.dart';\nimport 'package:get/route_manager.dart';\nimport 'package:getter/x.dart';",
        ),
        "import 'package:fluxy/get.dart';\nimport 'package:fluxy/route_manager.dart';\nimport 'package:getter/x.dart';",
      );
    });
  });

  group('map', () {
    test('comments and blank lines', () {
      final map = RenameMap.parse('# header\n\nA B # trailing\n  # indented\n');
      expect(map.length, 1);
      expect(map.words['A']!.to, 'B');
    });

    test('an all-comment map is empty', () {
      expect(RenameMap.parse('# A B\n# C D').isEmpty, isTrue);
    });

    test('bad lines name the line', () {
      expect(
        () => RenameMap.parse('A B\nC', source: 'm.txt'),
        throwsA(
          isA<RenameMapException>().having(
            (e) => e.message,
            'message',
            startsWith('m.txt:2:'),
          ),
        ),
      );
      expect(
        () => RenameMap.parse('A B C'),
        throwsA(isA<RenameMapException>()),
      );
      expect(() => RenameMap.parse('A 1B'), throwsA(isA<RenameMapException>()));
    });

    test('a name mapped twice', () {
      expect(
        () => RenameMap.parse('A B\nA C'),
        throwsA(isA<RenameMapException>()),
      );
    });

    test('a trailing ( on both sides, members only', () {
      expect(
        () => RenameMap.parse('Get.to( Nav.to'),
        throwsA(isA<RenameMapException>()),
      );
      expect(
        () => RenameMap.parse('back( pop('),
        throwsA(isA<RenameMapException>()),
      );
      expect(
        RenameMap.parse('Get.to( Nav.to(').members['Get']!.single.callOnly,
        isTrue,
      );
    });

    test('a URI prefix pair needs / on both sides', () {
      expect(
        () => RenameMap.parse('package:get/ package:fluxy'),
        throwsA(isA<RenameMapException>()),
      );
    });
  });
}
