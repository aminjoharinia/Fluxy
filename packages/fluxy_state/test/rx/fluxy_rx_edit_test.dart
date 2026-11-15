import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_state/fluxy_state.dart';

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('workers keep working after every worker was disposed', () {
    test('ever after a disposed ever still fires', () async {
      final rx = 0.obs;
      final first = <int>[];
      final w1 = ever<int>(rx, first.add);
      rx.value = 1;
      await _tick();
      w1.dispose();
      await _tick();

      final second = <int>[];
      ever<int>(rx, second.add);
      rx.value = 2;
      await _tick();
      expect(first, [1]);
      expect(second, [2], reason: 'used to stay silent');
    });

    test('listen / cancel / listen again', () async {
      final rx = 'a'.obs;
      final seen = <String>[];
      final sub1 = rx.listen(seen.add);
      rx.value = 'b';
      await _tick();
      await sub1.cancel();
      rx.value = 'c'; // nobody listening
      await _tick();
      final sub2 = rx.listen(seen.add);
      rx.value = 'd';
      await _tick();
      await sub2.cancel();
      expect(seen, ['b', 'd']);
    });

    test('the stream does not keep a listener while nobody listens', () async {
      final rx = 0.obs;
      expect(rx.listenersLength, 0);
      final sub = rx.listen((_) {});
      expect(rx.listenersLength, 1);
      await sub.cancel();
      expect(rx.listenersLength, 0);
    });
  });

  group('copy-on-write helpers', () {
    test('mapWith / listWith / listWithout / listReplaced', () {
      final src = {'a': 1, 'b': 2};
      expect(mapWith(src, {'b': 3}), {'a': 1, 'b': 3});
      expect(src, {'a': 1, 'b': 2});
      expect(listWith([1], 2), [1, 2]);
      expect(listWith(null, 2), [2]);
      expect(listWithout([1, 2, 3], 1), [1, 3]);
      expect(listReplaced([1, 2, 3], 1, 9), [1, 9, 3]);
    });

    test('updatedIn copies only the path, shares the rest', () {
      final shared = {'keep': true};
      final root = {
        'Places': [
          {'Name': 'A', 'Meta': shared},
        ],
        'Other': shared,
      };
      final next = updatedIn(root, ['Places', 0, 'Name'], (_) => 'B') as Map;
      expect((next['Places'] as List)[0]['Name'], 'B');
      expect((root['Places'] as List)[0]['Name'], 'A', reason: 'not in place');
      expect(identical(next['Other'], shared), isTrue);
      expect(identical((next['Places'] as List)[0]['Meta'], shared), isTrue);
    });

    test('RxMap document edits notify once and keep the old tree', () {
      final doc = <String, dynamic>{
        'Places': [
          {'Name': 'A', 'Sections': <dynamic>[]},
        ],
      }.obs;
      final before = doc['Places'];
      var calls = 0;
      doc.addListener(() => calls++);

      doc.setIn(['Places', 0, 'Name'], 'B');
      doc.patchIn(['Places', 0], {'Floor': 2});
      doc.editListIn(['Places', 0, 'Sections'], (l) => l.add('S'));
      expect(calls, 3);
      expect(doc['Places'][0], {
        'Name': 'B',
        'Sections': ['S'],
        'Floor': 2,
      });
      expect((before as List)[0]['Name'], 'A');
    });

    test('RxList / RxMap item edits', () {
      final list = <Map<String, dynamic>>[
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ].obs;
      list.patch(0, {'on': true});
      expect(list[0], {'id': 1, 'on': true});
      var calls = 0;
      list.addListener(() => calls++);
      list.reorder(0, 3);
      expect(list.map((e) => e['id']), [2, 3, 1]);
      expect(calls, 1, reason: 'one notification per reorder');

      final old = list[0];
      list.replaceItem(old, {'id': 20});
      expect(list[0], {'id': 20});

      final map = <String, dynamic>{}.obs;
      map.addEntry('tags', 'x');
      map.addEntry('tags', 'y');
      map.removeEntry('tags', 'x');
      expect(map['tags'], ['y']);
      map.removeEntryAt('tags', 0);
      expect(map['tags'], isEmpty);
    });
  });

  group('watchRx and RxSlice', () {
    test('watchRx runs in a microtask with the value at change time',
        () async {
      final rx = 0.obs;
      final seen = <int>[];
      final w = watchRx(rx, seen.add);
      rx.value = 1;
      expect(seen, isEmpty);
      await _tick();
      expect(seen, [1]);
      w.dispose();
      rx.value = 2;
      await _tick();
      expect(seen, [1]);
    });

    test('RxSlice notifies only when the selected part is a new object', () {
      final doc = <String, dynamic>{
        'a': {'n': 1},
        'b': {'n': 1},
      }.obs;
      final slice = RxSlice<Object?>([doc], () => doc.peek['a']);
      var calls = 0;
      slice.addListener(() => calls++);

      doc.patch('b', {'n': 2}); // 'a' is shared, same object
      expect(calls, 0);
      doc.patch('a', {'n': 2});
      expect(calls, 1);
      expect(slice.peek, {'n': 2});
      slice.dispose();
      doc.patch('a', {'n': 3});
      expect(calls, 1);
    });
  });

  test('debug warning when an Rx gets the same collection it holds', () {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    try {
      final rx = Rx<Map<String, int>>({'a': 1});
      rx.value = {'a': 1}; // a new object: no warning
      final held = rx.peek;
      held['a'] = 2; // in place
      rx.value = held; // same object: warns, does not notify
    } finally {
      debugPrint = original;
    }
    expect(logs.where((l) => l.contains('same')).length, 1);
  });
}
