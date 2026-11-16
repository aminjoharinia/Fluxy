import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_utils/fluxy_utils.dart';

void main() {
  test('jobs run in order', () async {
    final q = FluxyQueue();
    final log = <int>[];
    final a = q.add(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      log.add(1);
      return 1;
    });
    final b = q.add(() {
      log.add(2);
      return 2;
    });
    expect(await a, 1);
    expect(await b, 2);
    expect(log, [1, 2]);
  });

  test('a job that throws an Error fails its future and the queue goes on',
      () async {
    final q = FluxyQueue();
    final failed = q.add<void>(() async => throw StateError('boom'));
    final next = q.add(() async => 7);
    await expectLater(failed, throwsStateError);
    expect(await next, 7);
  });

  test('a job that throws a non-Exception object fails its future', () async {
    final q = FluxyQueue();
    final failed = q.add<void>(() => throw 'text');
    await expectLater(failed, throwsA('text'));
    expect(await q.add(() => 1), 1);
  });

  test('cancelAllJobs fails waiting jobs and does not start them', () async {
    final q = FluxyQueue();
    var ran = false;
    final running = q.add(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'done';
    });
    final waiting = q.add(() => ran = true);
    q.cancelAllJobs();
    await expectLater(waiting, throwsA(isA<FluxyQueueCancelledException>()));
    expect(await running, 'done');
    expect(ran, false);
    expect(await q.add(() => 3), 3);
  });

  test('cancelling a job nobody listens to is not an uncaught error',
      () async {
    final q = FluxyQueue();
    q.add(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    q.add(() {});
    q.cancelAllJobs();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}
