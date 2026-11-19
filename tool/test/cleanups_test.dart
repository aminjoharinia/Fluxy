import 'package:test/test.dart';

import '../src/cleanups.dart';
import '../src/rename_map.dart';

void main() {
  group('refresh()', () {
    test('dropped after a write to the same receiver that always notifies', () {
      const source = '''
void f() {
  items[i] = item;
  items.refresh();
  rows.add(row);
  rows.refresh();
  ctrl.list.removeWhere((e) {
    return e.gone;
  });
  ctrl.list.refresh();
  groups[key] ??= [];
  groups.refresh();
  m.update(k, (v) => v + 1);
  m.refresh();
}
''';
      final r = cleanup(source);
      expect(r.changes, 5);
      expect(r.source, '''
void f() {
  items[i] = item;
  rows.add(row);
  ctrl.list.removeWhere((e) {
    return e.gone;
  });
  groups[key] ??= [];
  m.update(k, (v) => v + 1);
}
''');
      expect(r.notes, isEmpty);
    });

    test('kept and reported when the write may not notify, or is elsewhere',
        () {
      const source = '''
void f() {
  item.finalPrice = 3;
  items.refresh();
  list.value = loaded;
  list.refresh();
  map.assignAll(map);
  map.refresh();
  other.add(1);
  rows.refresh();
  if (x) {
    rows.add(1);
  }
  rows.refresh();
}
''';
      final r = cleanup(source);
      expect(r.changes, 0);
      expect(r.source, source);
      expect(r.notes.map((n) => n.line), [3, 5, 7, 9, 13]);
      expect(r.notes.first.message, startsWith('items.refresh() kept'));
    });

    test('looks back past statements that write nothing (a save to disk)',
        () {
      const source = '''
Future<void> f() async {
  list[idx] = acc;
  await db?.write(dbKey, list.toList());
  print(list.length);
  list.refresh();
}
''';
      final r = cleanup(source);
      expect(r.changes, 1);
      expect(r.source, isNot(contains('list.refresh()')));
    });

    test('an in-place edit after the write keeps the refresh()', () {
      for (final between in [
        'mgr.markDone(acc);', // a call that does not read the list
        "acc['x'] = 2;",
        'acc.count++;',
        'acc.items.add(3);',
      ]) {
        final source = 'void f() {\n  list[0] = acc;\n  $between\n'
            '  list.refresh();\n}\n';
        final r = cleanup(source);
        expect(r.changes, 0, reason: between);
        expect(r.notes.single.line, 4, reason: between);
      }
    });

    test('no further back than $maxLookBack statements', () {
      final calls = List.filled(maxLookBack, '  save(a.toList());\n').join();
      final r = cleanup('void f() {\n  a.add(1);\n$calls  a.refresh();\n}\n');
      expect(r.changes, 0);
    });

    test('the first statement of a block is reported, not dropped', () {
      final r = cleanup('void f() {\n  rows.refresh();\n}\n');
      expect(r.changes, 0);
      expect(r.notes.single.line, 2);
    });

    test('not a statement of its own: left alone, not reported', () {
      const source = 'void f() => rows.refresh();\nvar g = () { return a.refresh(); };\n';
      final r = cleanup(source);
      expect(r.changes, 0);
      expect(r.notes, isEmpty);
    });

    test('in comments and strings: left alone', () {
      const source = '''
void f() {
  rows.add(1);
  // rows.refresh();
  print('rows.refresh();');
}
''';
      final r = cleanup(source);
      expect(r.source, source);
      expect(r.notes, isEmpty);
    });

    test('a trailing comment keeps its line', () {
      final r = cleanup('void f() {\n  a.add(1);\n  a.refresh(); // why\n}\n');
      expect(r.source, 'void f() {\n  a.add(1);\n  // why\n}\n');
    });

    test('dropRefresh false reports instead of dropping', () {
      const source = 'void f() {\n  a.add(1);\n  a.refresh();\n}\n';
      final r = cleanup(source, dropRefresh: false);
      expect(r.source, source);
      expect(r.notes.single.message, contains('redundant'));
    });

    test('spaces around dots and a multi-line receiver', () {
      const source = 'void f() {\n  c . rows\n      .add(1);\n  c.rows\n      .refresh();\n}\n';
      final r = cleanup(source);
      expect(r.changes, 1);
      expect(r.source, 'void f() {\n  c . rows\n      .add(1);\n}\n');
    });
  });

  group('deep package:get imports', () {
    test('become the whole library, or go when it is already imported', () {
      const source = '''
import 'package:get/get.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/state_manager.dart';
import "package:get/get_rx/src/rx_types/rx_types.dart" show RxInt;
''';
      final r = cleanup(source);
      expect(r.source, '''
import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import "package:get/get.dart" show RxInt;
''');
      expect(r.changes, 2);
      expect(r.notes.map((n) => n.line), [2, 4]);
    });

    test('the first deep import is kept as the library, the next one goes',
        () {
      const source = '''
import 'package:get/a/b.dart';
import 'package:get/c/d.dart';
// import 'package:get/e/f.dart';
''';
      final r = cleanup(source);
      expect(r.source, '''
import 'package:get/get.dart';
// import 'package:get/e/f.dart';
''');
    });
  });

  group('old names in strings', () {
    final map = RenameMap.parse('''
Get Fluxy
GetxController FluxyController
package:get/get.dart package:fluxy/fluxy.dart
''');

    test('reported once per literal, with the line', () {
      const source = '''
import 'package:get/get.dart';
void main() {
  expect(src.contains('Get.put(UsersController())'), isTrue);
  print('Get started');
  print("class A extends GetxController");
  print('\${Get.find<A>()}');
  final p = 'package:get/get.dart';
}
''';
      final notes = cleanup(source, map: map).notes;
      expect(notes.map((n) => n.line), [3, 5, 7]);
      expect(notes[0].message, contains('Get'));
      expect(notes[1].message, contains('GetxController'));
      expect(notes[2].message, contains('package:get/'));
    });
  });

  test('mask keeps offsets and line breaks', () {
    const source = "a('x\\n') /* c\n */ b; r'\$y' \"\${f('}')}\" z";
    final masked = mask(source);
    expect(masked.length, source.length);
    expect(masked.split('\n').length, source.split('\n').length);
    expect(masked.contains('a('), isTrue);
    expect(masked.contains('b;'), isTrue);
    expect(masked.trimRight().endsWith('z'), isTrue);
    expect(masked.contains('x'), isFalse);
    expect(masked.contains('f('), isFalse);
  });
}
