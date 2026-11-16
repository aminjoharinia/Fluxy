import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_state/fluxy_state.dart';

class _Rooms extends FluxyController with StateMixin<List<String>> {}

/// Exhaustive: adding a case to FluxyStatus would make this a compile error.
String describe(FluxyStatus<int> status) => switch (status) {
      SuccessStatus(:final data) => 'success $data',
      LoadingStatus(isRefreshing: true, :final data) => 'refreshing $data',
      LoadingStatus() => 'loading',
      ErrorStatus(:final error, :final data) => 'error $error ($data)',
      EmptyStatus() => 'empty',
    };

void main() {
  group('GetStatus', () {
    test('sealed switch, data carried through loading and error', () {
      FluxyStatus<int> s = FluxyStatus<int>.loading();
      expect(describe(s), 'loading');
      expect(s.hasData, isFalse);

      s = FluxyStatus.success(7);
      expect(describe(s), 'success 7');

      s = s.toLoading();
      expect(describe(s), 'refreshing 7');
      expect(s.isRefreshing, isTrue);
      expect(s.data, 7);

      s = s.toError('offline');
      expect(describe(s), 'error offline (7)');
      expect(s.hasData, isTrue);
      expect(s.errorMessage, 'offline');

      expect(describe(FluxyStatus<int>.empty()), 'empty');
    });

    test('equality includes the carried data', () {
      expect(const LoadingStatus<int>(), const LoadingStatus<int>());
      expect(const LoadingStatus<int>.withData(1),
          isNot(const LoadingStatus<int>()));
      expect(const ErrorStatus<int>('x'), const ErrorStatus<int>('x'));
    });

    test('a nullable data type can carry null as data', () {
      final s = FluxyStatus<int?>.success(null).toLoading();
      expect(s.hasData, isTrue);
      expect(s.data, isNull);
    });
  });

  group('StateMixin', () {
    test('setLoading / setError keep the data shown so far', () {
      final c = _Rooms();
      c.setSuccess(['kitchen']);
      c.setLoading();
      expect(c.status.isRefreshing, isTrue);
      expect(c.status.data, ['kitchen']);
      c.setError('timeout');
      expect(c.status.isError, isTrue);
      expect(c.status.data, ['kitchen']);
    });

    testWidgets('obx keeps showing the data while refreshing',
        (tester) async {
      final c = _Rooms();
      Widget app({bool skip = true}) => MaterialApp(
            home: c.obx((rooms) => Text(rooms.join(',')),
                onLoading: const Text('spinner'), skipLoadingOnRefresh: skip),
          );
      await tester.pumpWidget(app());
      expect(find.text('spinner'), findsOneWidget, reason: 'no data yet');

      c.setSuccess(['a', 'b']);
      await tester.pump();
      c.setLoading();
      await tester.pump();
      expect(find.text('a,b'), findsOneWidget);

      await tester.pumpWidget(app(skip: false));
      expect(find.text('spinner'), findsOneWidget);
    });

    test('futurize keeps data on reload and records the stack trace',
        () async {
      final c = _Rooms();
      c.futurize(() async => ['a']);
      await Future<void>.delayed(Duration.zero);
      c.futurize(() async => throw StateError('down'));
      expect(c.status.isRefreshing, isTrue);
      await Future<void>.delayed(Duration.zero);
      final status = c.status as ErrorStatus<List<String>>;
      expect(status.data, ['a']);
      expect(status.stackTrace, isNotNull);
    });
  });

  test('RxFuture: a reload keeps the old data, a failure too', () async {
    var fail = false;
    final f = RxFuture(() async {
      if (fail) throw StateError('x');
      return 1;
    });
    await Future<void>.delayed(Duration.zero);
    final reload = f.reload();
    expect(f.value.isRefreshing, isTrue);
    await reload;
    fail = true;
    await f.reload();
    expect(f.value.isError, isTrue);
    expect(f.value.data, 1);
  });

  group('RxCommand', () {
    test('droppable: a second call while running joins the first', () async {
      final gate = Completer<int>();
      var calls = 0;
      final cmd = RxCommand(() {
        calls++;
        return gate.future;
      });
      expect(cmd.value, isA<EmptyStatus<int>>());
      final first = cmd.run();
      final second = cmd.run();
      expect(cmd.isRunning, isTrue);
      gate.complete(5);
      expect(await first, const SuccessStatus(5));
      expect(await second, const SuccessStatus(5));
      expect(calls, 1);
      expect(cmd.value, const SuccessStatus(5));

      await cmd.run();
      expect(calls, 2, reason: 'a new run once the first is done');
    });

    test('restartable: only the newest result counts', () async {
      final gates = <Completer<String>>[];
      final cmd = RxCommand(() {
        final c = Completer<String>();
        gates.add(c);
        return c.future;
      }, mode: CommandMode.restartable);
      final old = cmd.run();
      final latest = cmd.run();
      gates[1].complete('new');
      await latest;
      expect(cmd.value.data, 'new');
      gates[0].complete('old');
      expect(await old, const SuccessStatus('old'),
          reason: 'the caller still gets its own result');
      expect(cmd.value.data, 'new', reason: 'but the status ignores it');
    });

    test('sequential: one after another, in call order', () async {
      final log = <String>[];
      var n = 0;
      final cmd = RxCommand(() async {
        final i = ++n;
        log.add('start $i');
        await Future<void>.delayed(Duration.zero);
        log.add('end $i');
        return i;
      }, mode: CommandMode.sequential);
      final a = cmd.run();
      final b = cmd.run();
      expect(cmd.isRunning, isTrue);
      await Future.wait([a, b]);
      expect(log, ['start 1', 'end 1', 'start 2', 'end 2']);
      expect(cmd.value, const SuccessStatus(2));
    });

    test('concurrent: all at once, settles when all are done', () async {
      final gates = [Completer<int>(), Completer<int>()];
      var i = 0;
      final cmd =
          RxCommand(() => gates[i++].future, mode: CommandMode.concurrent);
      cmd.run();
      cmd.run();
      gates[0].complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(cmd.isRunning, isTrue, reason: 'one still in flight');
      expect(cmd.value.data, 1);
      gates[1].complete(2);
      await Future<void>.delayed(Duration.zero);
      expect(cmd.value, const SuccessStatus(2));
    });

    test('an error keeps the last data and never throws from run', () async {
      var fail = false;
      final cmd = RxCommand(() async {
        if (fail) throw ArgumentError('bad');
        return 'ok';
      });
      await cmd.run();
      fail = true;
      final result = await cmd.run();
      expect(result.isError, isTrue);
      expect(cmd.value.isError, isTrue);
      expect(cmd.value.data, 'ok');
    });

    test('cancel ignores the run in flight and skips queued ones', () async {
      final gate = Completer<int>();
      var calls = 0;
      final cmd = RxCommand(() {
        calls++;
        return gate.future;
      }, mode: CommandMode.sequential);
      cmd.run();
      final queued = cmd.run();
      cmd.cancel();
      expect(cmd.value, isA<EmptyStatus<int>>());
      gate.complete(1);
      await queued;
      expect(calls, 1, reason: 'the queued run was skipped');
      expect(cmd.value, isA<EmptyStatus<int>>());
    });
  });
}
