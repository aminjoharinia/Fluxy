// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter_test/flutter_test.dart';
import 'same_name/a.dart' as same_a;
import 'same_name/b.dart' as same_b;
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

import 'util/matcher.dart' as m;

class Mock {
  static Future<String> test() async {
    await Future.delayed(Duration.zero);
    return 'test';
  }
}

abstract class MyController with FluxyLifeCycleMixin {}

class DisposableController extends MyController {}

// ignore: one_member_abstracts
abstract class Service {
  String post();
}

class Api implements Service {
  @override
  String post() {
    return 'test';
  }
}

void main() {
  fluxyKeyTests();

  TestWidgetsFlutterBinding.ensureInitialized();
  test('Get.put test', () async {
    final instance = Fluxy.put<Controller>(Controller());
    expect(instance, Fluxy.find<Controller>());
    Fluxy.resetInstance();
  });

  test('Get start and delete called just one time', () async {
    Fluxy
      ..put(Controller())
      ..put(Controller());

    final controller = Fluxy.find<Controller>();
    expect(controller.init, 1);

    Fluxy
      ..delete<Controller>()
      ..delete<Controller>();
    expect(controller.close, 1);
    Fluxy.resetInstance();
  });

  test('Get.put tag test', () async {
    final instance = Fluxy.put<Controller>(Controller(), tag: 'one');
    final instance2 = Fluxy.put<Controller>(Controller(), tag: 'two');
    expect(instance == instance2, false);
    expect(Fluxy.find<Controller>(tag: 'one') == Fluxy.find<Controller>(tag: 'two'),
        false);
    expect(Fluxy.find<Controller>(tag: 'one') == Fluxy.find<Controller>(tag: 'one'),
        true);
    expect(Fluxy.find<Controller>(tag: 'two') == Fluxy.find<Controller>(tag: 'two'),
        true);
    Fluxy.resetInstance();
  });

  test('Get.lazyPut tag test', () async {
    Fluxy.lazyPut<Controller>(() => Controller(), tag: 'one');
    Fluxy.lazyPut<Controller>(() => Controller(), tag: 'two');

    expect(Fluxy.find<Controller>(tag: 'one') == Fluxy.find<Controller>(tag: 'two'),
        false);
    expect(Fluxy.find<Controller>(tag: 'one') == Fluxy.find<Controller>(tag: 'one'),
        true);
    expect(Fluxy.find<Controller>(tag: 'two') == Fluxy.find<Controller>(tag: 'two'),
        true);
    Fluxy.resetInstance();
  });

  test('Get.lazyPut test', () async {
    final controller = Controller();
    Fluxy.lazyPut<Controller>(() => controller);
    final ct1 = Fluxy.find<Controller>();
    expect(ct1, controller);
    Fluxy.resetInstance();
  });

  test('a lazyPut builder stays after delete', () async {
    Fluxy.lazyPut<Controller>(() => Controller());
    Fluxy.find<Controller>().increment();

    expect(Fluxy.find<Controller>().count, 1);
    Fluxy.delete<Controller>();
    expect(Fluxy.find<Controller>().count, 0);
    Fluxy.resetInstance();
  });

  test('delete(force: true) removes a lazyPut registration', () async {
    Fluxy.lazyPut<Controller>(() => Controller());
    Fluxy.find<Controller>().increment();

    expect(Fluxy.find<Controller>().count, 1);
    Fluxy.delete<Controller>(force: true);
    expect(() => Fluxy.find<Controller>(),
        throwsA(const m.TypeMatcher<DependencyNotFound>()));
    Fluxy.resetInstance();
  });

  test('Get.reloadInstance test', () async {
    Fluxy.lazyPut<Controller>(() => Controller());
    var ct1 = Fluxy.find<Controller>();
    ct1.increment();
    expect(ct1.count, 1);
    ct1 = Fluxy.find<Controller>();
    expect(ct1.count, 1);
    Fluxy.reload<Controller>();
    ct1 = Fluxy.find<Controller>();
    expect(ct1.count, 0);
    Fluxy.resetInstance();
  });

  test('GetxService test', () async {
    Fluxy.lazyPut<PermanentService>(() => PermanentService());
    var sv1 = Fluxy.find<PermanentService>();
    var sv2 = Fluxy.find<PermanentService>();
    expect(sv1, sv2);
    expect(Fluxy.isRegistered<PermanentService>(), true);
    Fluxy.delete<PermanentService>();
    expect(Fluxy.isRegistered<PermanentService>(), true);
    Fluxy.delete<PermanentService>(force: true);
    expect(Fluxy.isRegistered<PermanentService>(), false);
    Fluxy.resetInstance();
  });

  test('Get.lazyPut with abstract class test', () async {
    final api = Api();
    Fluxy.lazyPut<Service>(() => api);
    final ct1 = Fluxy.find<Service>();
    expect(ct1, api);
    Fluxy.resetInstance();
  });

  test('Get.create with abstract class test', () async {
    Fluxy.spawn<Service>(() => Api());
    final ct1 = Fluxy.find<Service>();
    final ct2 = Fluxy.find<Service>();
    // expect(ct1 is Service, true);
    // expect(ct2 is Service, true);
    expect(ct1 == ct2, false);
    Fluxy.resetInstance();
  });

  group('test put, delete and check onInit execution', () {
    tearDownAll(Fluxy.resetInstance);

    test('Get.put test with init check', () async {
      final instance = Fluxy.put(DisposableController());
      expect(instance, Fluxy.find<DisposableController>());
      expect(instance.initialized, true);
    });

    test('Get.delete test with disposable controller', () async {
      // Fluxy.put(DisposableController());
      expect(Fluxy.delete<DisposableController>(), true);
      expect(() => Fluxy.find<DisposableController>(),
          throwsA(const m.TypeMatcher<DependencyNotFound>()));
    });

    test('Get.put test after delete with disposable controller and init check',
        () async {
      final instance = Fluxy.put<DisposableController>(DisposableController());
      expect(instance, Fluxy.find<DisposableController>());
      expect(instance.initialized, true);
    });
  });

  group('Get.replace test for replacing parent instance that is', () {
    tearDown(Fluxy.resetInstance);
    test('temporary', () async {
      Fluxy.put(DisposableController());
      Fluxy.replace<DisposableController>(Controller());
      final instance = Fluxy.find<DisposableController>();
      expect(instance is Controller, isTrue);
      expect((instance as Controller).init, greaterThan(0));
    });

    test('permanent', () async {
      Fluxy.put(DisposableController(), permanent: true);
      Fluxy.replace<DisposableController>(Controller());
      final instance = Fluxy.find<DisposableController>();
      expect(instance is Controller, isTrue);
      expect((instance as Controller).init, greaterThan(0));
    });

    test('tagged temporary', () async {
      const tag = 'tag';
      Fluxy.put(DisposableController(), tag: tag);
      Fluxy.replace<DisposableController>(Controller(), tag: tag);
      final instance = Fluxy.find<DisposableController>(tag: tag);
      expect(instance is Controller, isTrue);
      expect((instance as Controller).init, greaterThan(0));
    });

    test('tagged permanent', () async {
      const tag = 'tag';
      Fluxy.put(DisposableController(), permanent: true, tag: tag);
      Fluxy.replace<DisposableController>(Controller(), tag: tag);
      final instance = Fluxy.find<DisposableController>(tag: tag);
      expect(instance is Controller, isTrue);
      expect((instance as Controller).init, greaterThan(0));
    });

    test('a generic parent type', () async {
      const tag = 'tag';
      Fluxy.put<MyController>(DisposableController(), permanent: true, tag: tag);
      Fluxy.replace<MyController>(Controller(), tag: tag);
      final instance = Fluxy.find<MyController>(tag: tag);
      expect(instance is Controller, isTrue);
      expect((instance as Controller).init, greaterThan(0));
    });
  });

  group('Get.lazyReplace replaces parent instance', () {
    tearDown(Fluxy.resetInstance);
    test('a put instance', () async {
      Fluxy.put(DisposableController());
      Fluxy.lazyReplace<DisposableController>(() => Controller());
      final instance = Fluxy.find<DisposableController>();
      expect(instance, isA<Controller>());
      expect((instance as Controller).init, greaterThan(0));
    });

    test('keeps the builder after delete', () async {
      Fluxy.put(DisposableController());
      Fluxy.lazyReplace<DisposableController>(() => Controller());
      expect(Fluxy.find<DisposableController>(), isA<Controller>());
      (Fluxy.find<DisposableController>() as Controller).increment();

      expect((Fluxy.find<DisposableController>() as Controller).count, 1);
      Fluxy.delete<DisposableController>();
      expect((Fluxy.find<DisposableController>() as Controller).count, 0);
    });

    test('when the parent is permanent', () async {
      Fluxy.put(DisposableController(), permanent: true);
      Fluxy.lazyReplace<DisposableController>(() => Controller());
      final instance = Fluxy.find<DisposableController>();
      expect(instance, isA<Controller>());
      (instance as Controller).increment();

      expect((Fluxy.find<DisposableController>() as Controller).count, 1);
      // The replacement keeps the parent's permanent flag.
      expect(Fluxy.delete<DisposableController>(), isFalse);
      expect((Fluxy.find<DisposableController>() as Controller).count, 1);
    });
  });

  group('Get.findOrNull test', () {
    tearDown(Fluxy.resetInstance);
    test('checking results', () async {
      Fluxy.put<int>(1);
      int? result = Fluxy.findOrNull<int>();
      expect(result, 1);

      Fluxy.delete<int>();
      result = Fluxy.findOrNull<int>();
      expect(result, null);
    });
  });
}

class PermanentService extends FluxyService {}

class Controller extends DisposableController {
  int init = 0;
  int close = 0;
  int count = 0;
  @override
  void onInit() {
    init++;
    super.onInit();
  }

  @override
  void onClose() {
    close++;
    super.onClose();
  }

  void increment() {
    count++;
  }
}

class _Foo {}

class _FooBar {}

void fluxyKeyTests() {
  group('instance keys are Types, not type names', () {
    tearDown(Fluxy.resetInstance);

    test('two classes with the same name from different libraries', () {
      Fluxy.put(same_a.Controller());
      Fluxy.put(same_b.Controller());
      expect(Fluxy.find<same_a.Controller>().from, 'a');
      expect(Fluxy.find<same_b.Controller>().from, 'b');
    });

    test('a tag can no longer collide with another type name', () {
      // Old keys: '_Foo' + 'Bar' == '_FooBar'.
      final fooBar = _FooBar();
      Fluxy.put(fooBar);
      Fluxy.put(_Foo(), tag: 'Bar');
      expect(Fluxy.find<_FooBar>(), same(fooBar));
      expect(Fluxy.isRegistered<_Foo>(tag: 'Bar'), isTrue);
      expect(Fluxy.isRegistered<_Foo>(), isFalse);
    });
  });
}
