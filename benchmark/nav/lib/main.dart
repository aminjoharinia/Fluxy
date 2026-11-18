// Navigation and dependency benchmark: route matching, push / pop, deep
// stacks, deep links, dialogs, find / put / delete and pages with bindings,
// in a release (AOT) macOS build. Only API shared by v1.0.0
// and v1.2.0 is used here; the rest is in adapter.dart.
//
//   flutter build macos --release --dart-define=BENCH_OUT=/path/out.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:fluxy/fluxy.dart';
import 'package:material_ui/material_ui.dart';

import 'adapter.dart';

const _out = String.fromEnvironment('BENCH_OUT');

FluxyPage _page(String name, {List<FluxyPage> children = const []}) =>
    FluxyPage(
      name: name,
      page: () => const SizedBox(width: 2, height: 2),
      transition: Transition.noTransition,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      children: children,
    );

class _Ctrl extends FluxyController {}

class _PageCtrl extends FluxyController {}

class _Bound extends Binding {
  @override
  List<Bind> dependencies() => [Bind.lazyPut<_PageCtrl>(() => _PageCtrl())];
}

List<FluxyPage> _pages() => [
      _page('/'),
      FluxyPage(
        name: '/bound',
        binding: _Bound(),
        page: () {
          Fluxy.find<_PageCtrl>();
          return const SizedBox(width: 2, height: 2);
        },
        transition: Transition.noTransition,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      for (var i = 0; i < 50; i++) _page('/p$i/:id'),
      for (var i = 0; i < 100; i++) _page('/s$i'),
      _page('/n', children: [
        _page('/a', children: [
          _page('/b', children: [
            _page('/c', children: [
              _page('/d', children: [_page('/:id')]),
            ]),
          ]),
        ]),
      ]),
    ];

Future<void> _frame() async {
  await Future<void>.delayed(Duration.zero);
  final binding = SchedulerBinding.instance;
  binding.handleBeginFrame(null);
  binding.handleDrawFrame();
}

void _check(bool ok, String what) {
  if (!ok) throw StateError('check failed: $what');
}

class _Scenario {
  _Scenario(this.name, this.ops, this.run);
  final String name;
  final int ops;
  final Future<void> Function() run;
}

Future<Map<String, Object?>> _measure(_Scenario s, {int samples = 15}) async {
  await s.run(); // warm-up
  final times = <int>[];
  for (var i = 0; i < samples; i++) {
    final sw = Stopwatch()..start();
    await s.run();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  final median = times[times.length ~/ 2];
  return {
    'scenario': s.name,
    'opsPerRun': s.ops,
    'medianUs': median,
    'usPerOp': median / s.ops,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FluxyApp.router(getPages: _pages(), initialRoute: '/'));
  for (var i = 0; i < 5; i++) {
    await _frame();
  }

  const addresses = ['/s99', '/p49/7', '/n/a/b/c/d/42', '/nope/x', '/s0'];
  final scenarios = [
    _Scenario('match', 10000, () async {
      var found = 0;
      for (var i = 0; i < 10000; i++) {
        if (match(addresses[i % addresses.length])) found++;
      }
      _check(found == 8000, 'matches');
    }),
    _Scenario('push + pop', 100, () async {
      for (var i = 0; i < 100; i++) {
        Fluxy.toNamed('/s${i % 100}');
        await _frame();
        Fluxy.back();
        await _frame();
      }
      _check(stackLength() == 1, 'stack back to one');
    }),
    _Scenario('push 100 deep', 100, () async {
      for (var i = 0; i < 100; i++) {
        Fluxy.toNamed('/s$i');
        await _frame();
      }
      _check(stackLength() == 101, 'stack of 101');
      Fluxy.offAllNamed('/');
      await _frame();
    }),
    _Scenario('deep link', 100, () async {
      for (var i = 0; i < 100; i++) {
        Fluxy.offAllNamed(i.isEven ? '/n/a/b/c/d/$i' : '/p${i % 50}/$i');
        await _frame();
      }
      _check(stackLength() == 1, 'one page');
      Fluxy.offAllNamed('/');
      await _frame();
    }),
    _Scenario('dialog open + close', 100, () async {
      for (var i = 0; i < 100; i++) {
        Fluxy.dialog(const SizedBox(width: 2, height: 2),
            transitionDuration: Duration.zero);
        await _frame();
        _check(Fluxy.isDialogOpen == true, 'dialog open');
        Fluxy.back();
        await _frame();
      }
      _check(Fluxy.isDialogOpen == false, 'dialog closed');
    }),
    _Scenario('di find', 100000, () async {
      Fluxy.put<_Ctrl>(_Ctrl());
      var n = 0;
      for (var i = 0; i < 100000; i++) {
        if (identical(Fluxy.find<_Ctrl>(), Fluxy.find<_Ctrl>())) n++;
      }
      _check(n == 100000, 'same instance');
      Fluxy.delete<_Ctrl>(force: true);
    }),
    _Scenario('di put + delete', 10000, () async {
      for (var i = 0; i < 10000; i++) {
        Fluxy.put<_Ctrl>(_Ctrl());
        Fluxy.delete<_Ctrl>(force: true);
      }
      _check(!Fluxy.isRegistered<_Ctrl>(), 'deleted');
      await _frame();
    }),
    _Scenario('di lazyPut + find + delete', 10000, () async {
      for (var i = 0; i < 10000; i++) {
        Fluxy.lazyPut<_Ctrl>(() => _Ctrl());
        Fluxy.find<_Ctrl>();
        Fluxy.delete<_Ctrl>(force: true);
      }
      _check(!Fluxy.isRegistered<_Ctrl>(), 'deleted');
      await _frame();
    }),
    _Scenario('page with bindings push + pop', 100, () async {
      for (var i = 0; i < 100; i++) {
        Fluxy.toNamed('/bound');
        await _frame();
        Fluxy.back();
        await _frame();
        await _frame();
      }
      _check(!Fluxy.isRegistered<_PageCtrl>(), 'page dependencies closed');
    }),
  ];

  final results = <Map<String, Object?>>[];
  for (final s in scenarios) {
    results.add(await _measure(s));
  }
  final json = const JsonEncoder.withIndent('  ').convert({'results': results});
  if (_out.isEmpty) {
    stdout.writeln(json);
  } else {
    File(_out).writeAsStringSync(json);
  }
  exit(0);
}
