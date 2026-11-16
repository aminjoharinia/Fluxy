import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'harness.dart';
import 'ui.dart';

/// The widget scenarios. Each library provides its reactive leaf widget.
abstract class WidgetSuite {
  /// Wraps the whole app (for example in a `ProviderScope`).
  Widget wrap(Widget child) => child;

  /// Creates [n] reactive values.
  void setup(int n);

  /// The reactive widget for value [i]; it must build `Leaf(value)`.
  Widget leaf(int i);

  /// A reactive widget that reads the one value every `sharedLeaf` shares
  /// (created in [setup]); it must build `Leaf(value)`.
  Widget sharedLeaf(int i);

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

Widget _tree(WidgetSuite suite, int n, {bool shared = false}) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: Wrap(children: [
          for (var i = 0; i < n; i++)
            shared ? suite.sharedLeaf(i) : suite.leaf(i)
        ]),
      ),
    );

/// Where the widget scenarios mount their tree. The UI shows it in a small
/// panel; the headless run makes it the whole app.
Widget benchHost() => ValueListenableBuilder<Widget>(
      valueListenable: _host,
      builder: (_, child, __) => child,
    );

Future<List<Map<String, Object?>>> runWidgets(
  WidgetSuite suite, {
  BenchSize size = BenchSize.normal,
  ScenarioStart? onStart,
  ScenarioResult? onResult,
}) async {
  final n = size.widgets;
  final results = <Map<String, Object?>>[];
  suite.setup(n);
  var counter = 1;

  Future<Map<String, Object?>> step(String id, Bench Function() make) async {
    await onStart?.call(id);
    final result = await measure(id, make,
        warmup: size.warmup,
        minSamples: size.minSamples,
        budget: const Duration(milliseconds: 2000));
    onResult?.call(result);
    return result;
  }

  results.add(await step('mount', () {
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
  }));

  results.add(await step('mountShared', () {
    return Bench(
      opsPerRun: n,
      run: () async {
        final before = Leaf.builds;
        _host.value = _tree(suite, n, shared: true);
        await pumpFrame();
        check(Leaf.builds - before == n,
            'mount built ${Leaf.builds - before} leaves, expected $n');
        _host.value = const SizedBox();
        await pumpFrame();
      },
    );
  }));

  _host.value = _tree(suite, n);
  await pumpFrame();

  results.add(await step('rebuildAll', () {
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
  }));

  var next = 0;
  results.add(await step('rebuildOne', () {
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
  }));

  _host.value = const SizedBox();
  await pumpFrame();
  suite.teardown();
  return results;
}

/// With `--dart-define=BENCH_OUT=...` (what `run.sh` does): runs everything
/// for one library with no UI, writes the JSON there and exits.
/// `--dart-define=BENCH_SIZE=tiny|normal|heavy|super` picks the workload.
///
/// Without it (the app opened by hand): shows the benchmark UI, which runs
/// the same scenarios on demand and charts them next to the saved results
/// of every library (`results/summary.json`).
Future<void> runBenchmarks({
  required String library,
  required CoreSuite core,
  required WidgetSuite widgets,
  String notes = '',
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  const out = String.fromEnvironment('BENCH_OUT');
  final size = BenchSize.fromKey(
      const String.fromEnvironment('BENCH_SIZE', defaultValue: 'normal'));
  if (out.isEmpty) {
    runApp(widgets.wrap(BenchApp(
      library: library,
      notes: notes,
      core: core,
      widgets: widgets,
    )));
    return;
  }
  runApp(widgets.wrap(Directionality(
    textDirection: TextDirection.ltr,
    child: benchHost(),
  )));
  await pumpFrame();

  // First, in a fresh heap (see measureMemory).
  final memory = await measureMemory(core);
  final coreResults = await runCore(core, size: size);
  final widgetResults = await runWidgets(widgets, size: size);

  final json = const JsonEncoder.withIndent('  ').convert({
    'library': library,
    'notes': notes,
    'size': size.key,
    'asyncNotify': core.asyncNotify,
    'dart': Platform.version,
    'os': Platform.operatingSystemVersion,
    'cpus': Platform.numberOfProcessors,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug',
    'results': [...coreResults, ...widgetResults, memory],
  });
  File(out).writeAsStringSync(json);
  exit(0);
}
