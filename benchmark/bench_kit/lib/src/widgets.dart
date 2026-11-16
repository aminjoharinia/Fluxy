import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'harness.dart';

/// The widget scenarios. Each library provides its reactive leaf widget.
abstract class WidgetSuite {
  /// Wraps the whole app (for example in a `ProviderScope`).
  Widget wrap(Widget child) => child;

  /// Creates [n] reactive values.
  void setup(int n);

  /// The reactive widget for value [i]; it must build `Leaf(value)`.
  Widget leaf(int i);

  /// Sets value [i].
  void write(int i, int value);

  void teardown();
}

/// The same cheap leaf for every library, so frames measure the reactive
/// layer, not text layout. Counts its builds.
class Leaf extends StatelessWidget {
  const Leaf(this.value, {super.key});
  final int value;

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return SizedBox(
      width: 2,
      height: 2,
      child: ColoredBox(color: Color(0xFF000000 | (value & 0xFFFFFF))),
    );
  }
}

final _host = ValueNotifier<Widget>(const SizedBox());

/// Lets pending notifications land, then builds, lays out and paints one
/// frame synchronously (no waiting for vsync).
Future<void> pumpFrame() async {
  await settle();
  final binding = SchedulerBinding.instance;
  binding.handleBeginFrame(null);
  binding.handleDrawFrame();
}

Widget _tree(WidgetSuite suite, int n) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: Wrap(children: [for (var i = 0; i < n; i++) suite.leaf(i)]),
      ),
    );

Future<List<Map<String, Object?>>> runWidgets(WidgetSuite suite) async {
  const n = 1000;
  final results = <Map<String, Object?>>[];
  suite.setup(n);
  var counter = 1;

  results.add(await measure('mount', () {
    return Bench(
      opsPerRun: n,
      run: () async {
        final before = Leaf.builds;
        _host.value = _tree(suite, n);
        await pumpFrame();
        check(Leaf.builds - before == n,
            'mount built ${Leaf.builds - before} leaves, expected $n');
        _host.value = const SizedBox();
        await pumpFrame();
      },
    );
  }, budget: const Duration(milliseconds: 2000)));

  _host.value = _tree(suite, n);
  await pumpFrame();

  results.add(await measure('rebuildAll', () {
    return Bench(
      opsPerRun: n,
      run: () async {
        final before = Leaf.builds;
        counter++;
        for (var i = 0; i < n; i++) {
          suite.write(i, counter * n + i);
        }
        await pumpFrame();
        check(Leaf.builds - before == n,
            'rebuilt ${Leaf.builds - before} leaves, expected $n');
      },
    );
  }, budget: const Duration(milliseconds: 2000)));

  var next = 0;
  results.add(await measure('rebuildOne', () {
    return Bench(
      opsPerRun: 1,
      run: () async {
        final before = Leaf.builds;
        counter++;
        next = (next + 7) % n;
        suite.write(next, counter * n + next);
        await pumpFrame();
        check(Leaf.builds - before == 1,
            'rebuilt ${Leaf.builds - before} leaves, expected 1');
      },
    );
  }, budget: const Duration(milliseconds: 2000)));

  _host.value = const SizedBox();
  await pumpFrame();
  suite.teardown();
  return results;
}

/// Runs everything for one library and writes the JSON to the path given
/// with `--dart-define=BENCH_OUT=...`, then exits.
Future<void> runBenchmarks({
  required String library,
  required CoreSuite core,
  required WidgetSuite widgets,
  String notes = '',
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(widgets.wrap(Directionality(
    textDirection: TextDirection.ltr,
    child: ValueListenableBuilder<Widget>(
      valueListenable: _host,
      builder: (_, child, __) => child,
    ),
  )));
  await pumpFrame();

  final coreResults = await runCore(core);
  final widgetResults = await runWidgets(widgets);

  const out = String.fromEnvironment('BENCH_OUT');
  final json = const JsonEncoder.withIndent('  ').convert({
    'library': library,
    'notes': notes,
    'asyncNotify': core.asyncNotify,
    'dart': Platform.version,
    'os': Platform.operatingSystemVersion,
    'cpus': Platform.numberOfProcessors,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug',
    'results': [...coreResults, ...widgetResults],
  });
  if (out.isEmpty) {
    // ignore: avoid_print
    print(json);
  } else {
    File(out).writeAsStringSync(json);
  }
  exit(0);
}
