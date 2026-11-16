import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

final _count = 0.obs;

class _OwningController extends FluxyController {
  final log = <String>[];
  late Computed<int> doubled;
  late Effect logger;
  late Worker worker;

  /// Field made outside onInit, handed over with own().
  late final tripled = own(Computed(() => _count.value * 3));

  late final Effect detached;

  @override
  void onInit() {
    super.onInit();
    doubled = Computed(() => _count.value * 2);
    logger = effect(() => log.add('effect ${_count.value}'));
    worker = ever(_count, (v) => log.add('ever $v'));
    detached = ReactiveOwner.untracked(() => effect(() => _count.value));
    onDispose(() => log.add('cleanup 1'));
    onDispose(() => log.add('cleanup 2'));
  }

  @override
  void onClose() {
    log.add('onClose');
    super.onClose();
  }
}

class _Child extends FluxyController {
  late Effect e;
  @override
  void onInit() {
    super.onInit();
    e = effect(() => _count.value);
  }
}

class _Parent extends FluxyController {
  late Effect e;
  late _Child child;
  @override
  void onInit() {
    super.onInit();
    child = Fluxy.put(_Child());
    e = effect(() => _count.value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Fluxy.resetInstance();
    _count.value = 0;
  });

  test('what onInit creates is disposed after onClose', () {
    final c = Fluxy.put(_OwningController());
    c.doubled.addListener(() {});
    expect(c.tripled.value, 0);
    _count.value = 1;
    expect(c.log, ['effect 0', 'ever 1', 'effect 1'],
        reason: 'ever runs inside the notify, effects right after it');

    Fluxy.delete<_OwningController>();
    expect(c.log.sublist(3), ['onClose', 'cleanup 2', 'cleanup 1'],
        reason: 'cleanups after onClose, newest first');
    expect(c.logger.isDisposed, isTrue);
    expect(c.worker.disposed, isTrue);
    expect(c.doubled.isDisposed, isTrue);
    expect(c.tripled.isDisposed, isTrue);
    expect(c.detached.isDisposed, isFalse, reason: 'made untracked');

    _count.value = 2;
    expect(c.log.last, 'cleanup 1', reason: 'nothing runs any more');
    c.detached.dispose();
  });

  test('disposing an owned object early is fine', () {
    final c = Fluxy.put(_OwningController());
    c.logger.dispose();
    c.doubled.dispose();
    c.worker.dispose();
    expect(() => Fluxy.delete<_OwningController>(), returnsNormally);
  });

  test('a controller put inside onInit owns its own effects', () {
    final p = Fluxy.put(_Parent());
    Fluxy.delete<_Child>();
    expect(p.child.e.isDisposed, isTrue);
    expect(p.e.isDisposed, isFalse);
    Fluxy.delete<_Parent>();
    expect(p.e.isDisposed, isTrue);
  });

  test('own() accepts the common disposables', () {
    final c = Fluxy.put(_OwningController());
    final rx = 0.obs;
    final sub = Stream<void>.periodic(const Duration(days: 1)).listen((_) {});
    final controller = StreamController<int>();
    final timer = Timer(const Duration(days: 1), () {});
    final notifier = ChangeNotifier();
    expect(c.own(rx), same(rx));
    c.own(sub);
    c.own(controller);
    c.own(timer);
    c.own(notifier);
    Fluxy.delete<_OwningController>();
    expect(rx.isDisposed, isTrue);
    expect(controller.isClosed, isTrue);
    expect(timer.isActive, isFalse);
  });

  test('own() rejects what it cannot dispose', () {
    final c = Fluxy.put(_OwningController());
    expect(() => c.own('text'), throwsArgumentError);
  });

  test('ReactiveOwner on its own', () {
    final owner = ReactiveOwner();
    final n = 0.obs;
    final seen = <int>[];
    owner.run(() => effect(() => seen.add(n.value)));
    expect(owner.length, 1);
    owner.dispose();
    n.value = 1;
    expect(seen, [0]);

    var ran = false;
    owner.onDispose(() => ran = true);
    expect(ran, isTrue, reason: 'added after dispose: runs at once');
  });

  test('a throwing cleanup is reported and the others still run', () {
    final reported = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => reported.add(d.exception);
    addTearDown(() => FlutterError.onError = previous);

    final owner = ReactiveOwner();
    var second = false;
    owner.onDispose(() => second = true);
    owner.onDispose(() => throw StateError('bad cleanup'));
    owner.dispose();
    expect(second, isTrue);
    expect(reported.single, isA<StateError>());
  });
}
